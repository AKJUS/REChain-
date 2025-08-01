// Copyright 2024 New Vector Ltd.
// Copyright 2022 The Matrix.org Foundation C.I.C.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.

package routing

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/matrix-org/gomatrix"
	"github.com/matrix-org/gomatrixserverlib/tokens"
	"github.com/matrix-org/util"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/sirupsen/logrus"

	"github.com/element-hq/dendrite/roomserver/types"

	appserviceAPI "github.com/element-hq/dendrite/appservice/api"
	"github.com/element-hq/dendrite/clientapi/httputil"
	"github.com/element-hq/dendrite/internal/eventutil"
	"github.com/element-hq/dendrite/internal/transactions"
	"github.com/element-hq/dendrite/roomserver/api"
	"github.com/element-hq/dendrite/setup/config"
	userapi "github.com/element-hq/dendrite/userapi/api"
	"github.com/matrix-org/gomatrixserverlib/spec"
)

// Unspecced server notice request
// https://github.com/matrix-org/synapse/blob/develop/docs/admin_api/server_notices.md
type sendServerNoticeRequest struct {
	UserID  string `json:"user_id,omitempty"`
	Content struct {
		MsgType string `json:"msgtype,omitempty"`
		Body    string `json:"body,omitempty"`
	} `json:"content,omitempty"`
	Type     string `json:"type,omitempty"`
	StateKey string `json:"state_key,omitempty"`
}

// nolint:gocyclo
// SendServerNotice sends a message to a specific user. It can only be invoked by an admin.
func SendServerNotice(
	req *http.Request,
	cfgNotices *config.ServerNotices,
	cfgClient *config.ClientAPI,
	userAPI userapi.ClientUserAPI,
	rsAPI api.ClientRoomserverAPI,
	asAPI appserviceAPI.AppServiceInternalAPI,
	device *userapi.Device,
	senderDevice *userapi.Device,
	txnID *string,
	txnCache *transactions.Cache,
) util.JSONResponse {
	if device.AccountType != userapi.AccountTypeAdmin {
		return util.JSONResponse{
			Code: http.StatusForbidden,
			JSON: spec.Forbidden("This API can only be used by admin users."),
		}
	}

	if txnID != nil {
		// Try to fetch response from transactionsCache
		if res, ok := txnCache.FetchTransaction(device.AccessToken, *txnID, req.URL); ok {
			return *res
		}
	}

	ctx := req.Context()
	var r sendServerNoticeRequest
	resErr := httputil.UnmarshalJSONRequest(req, &r)
	if resErr != nil {
		return *resErr
	}

	// check that all required fields are set
	if !r.valid() {
		return util.JSONResponse{
			Code: http.StatusBadRequest,
			JSON: spec.BadJSON("Invalid request"),
		}
	}

	userID, err := spec.NewUserID(r.UserID, true)
	if err != nil {
		return util.JSONResponse{
			Code: http.StatusBadRequest,
			JSON: spec.InvalidParam("invalid user ID"),
		}
	}

	// get rooms for specified user
	allUserRooms := []spec.RoomID{}
	// Get rooms the user is either joined, invited or has left.
	for _, membership := range []string{"join", "invite", "leave"} {
		userRooms, queryErr := rsAPI.QueryRoomsForUser(ctx, *userID, membership)
		if queryErr != nil {
			return util.ErrorResponse(queryErr)
		}
		allUserRooms = append(allUserRooms, userRooms...)
	}

	// get rooms of the sender
	senderUserID, err := spec.NewUserID(fmt.Sprintf("@%s:%s", cfgNotices.LocalPart, cfgClient.Matrix.ServerName), true)
	if err != nil {
		return util.JSONResponse{
			Code: http.StatusInternalServerError,
			JSON: spec.Unknown("internal server error"),
		}
	}
	senderRooms, err := rsAPI.QueryRoomsForUser(ctx, *senderUserID, "join")
	if err != nil {
		return util.ErrorResponse(err)
	}

	// check if we have rooms in common
	commonRooms := []spec.RoomID{}
	for _, userRoomID := range allUserRooms {
		for _, senderRoomID := range senderRooms {
			if userRoomID == senderRoomID {
				commonRooms = append(commonRooms, senderRoomID)
			}
		}
	}

	if len(commonRooms) > 1 {
		return util.ErrorResponse(fmt.Errorf("expected to find one room, but got %d", len(commonRooms)))
	}

	var (
		roomID      string
		roomVersion = rsAPI.DefaultRoomVersion()
	)

	// create a new room for the user
	if len(commonRooms) == 0 {
		powerLevelContent := eventutil.InitialPowerLevelsContent(senderUserID.String())
		powerLevelContent.Users[r.UserID] = -10 // taken from Synapse
		pl, err := json.Marshal(powerLevelContent)
		if err != nil {
			return util.ErrorResponse(err)
		}
		createContent := map[string]interface{}{}
		createContent["m.federate"] = false
		cc, err := json.Marshal(createContent)
		if err != nil {
			return util.ErrorResponse(err)
		}
		crReq := createRoomRequest{
			Invite:                    []string{r.UserID},
			Name:                      cfgNotices.RoomName,
			Visibility:                "private",
			Preset:                    spec.PresetPrivateChat,
			CreationContent:           cc,
			RoomVersion:               roomVersion,
			PowerLevelContentOverride: pl,
		}

		roomRes := createRoom(ctx, crReq, senderDevice, cfgClient, userAPI, rsAPI, asAPI, time.Now())

		switch data := roomRes.JSON.(type) {
		case createRoomResponse:
			roomID = data.RoomID

			// tag the room, so we can later check if the user tries to reject an invite
			serverAlertTag := gomatrix.TagContent{Tags: map[string]gomatrix.TagProperties{
				"m.server_notice": {
					Order: 1.0,
				},
			}}
			if err = saveTagData(req, r.UserID, roomID, userAPI, serverAlertTag); err != nil {
				util.GetLogger(ctx).WithError(err).Error("saveTagData failed")
				return util.JSONResponse{
					Code: http.StatusInternalServerError,
					JSON: spec.InternalServerError{},
				}
			}

		default:
			// if we didn't get a createRoomResponse, we probably received an error, so return that.
			return roomRes
		}
	} else {
		// we've found a room in common, check the membership
		deviceUserID, err := spec.NewUserID(r.UserID, true)
		if err != nil {
			return util.JSONResponse{
				Code: http.StatusForbidden,
				JSON: spec.Forbidden("userID doesn't have power level to change visibility"),
			}
		}

		roomID = commonRooms[0].String()
		membershipRes := api.QueryMembershipForUserResponse{}
		err = rsAPI.QueryMembershipForUser(ctx, &api.QueryMembershipForUserRequest{UserID: *deviceUserID, RoomID: roomID}, &membershipRes)
		if err != nil {
			util.GetLogger(ctx).WithError(err).Error("unable to query membership for user")
			return util.JSONResponse{
				Code: http.StatusInternalServerError,
				JSON: spec.InternalServerError{},
			}
		}
		if !membershipRes.IsInRoom {
			// re-invite the user
			res, err := sendInvite(ctx, senderDevice, roomID, r.UserID, "Server notice room", cfgClient, rsAPI, time.Now())
			if err != nil {
				return res
			}
		}
	}

	startedGeneratingEvent := time.Now()

	request := map[string]interface{}{
		"body":    r.Content.Body,
		"msgtype": r.Content.MsgType,
	}
	e, resErr := generateSendEvent(ctx, request, senderDevice, roomID, "m.room.message", nil, rsAPI, time.Now())
	if resErr != nil {
		logrus.Errorf("failed to send message: %+v", resErr)
		return *resErr
	}
	timeToGenerateEvent := time.Since(startedGeneratingEvent)

	var txnAndSessionID *api.TransactionID
	if txnID != nil {
		txnAndSessionID = &api.TransactionID{
			TransactionID: *txnID,
			SessionID:     device.SessionID,
		}
	}

	// pass the new event to the roomserver and receive the correct event ID
	// event ID in case of duplicate transaction is discarded
	startedSubmittingEvent := time.Now()
	if err := api.SendEvents(
		ctx, rsAPI,
		api.KindNew,
		[]*types.HeaderedEvent{
			{PDU: e},
		},
		device.UserDomain(),
		cfgClient.Matrix.ServerName,
		cfgClient.Matrix.ServerName,
		txnAndSessionID,
		false,
	); err != nil {
		util.GetLogger(ctx).WithError(err).Error("SendEvents failed")
		return util.JSONResponse{
			Code: http.StatusInternalServerError,
			JSON: spec.InternalServerError{},
		}
	}
	util.GetLogger(ctx).WithFields(logrus.Fields{
		"event_id":     e.EventID(),
		"room_id":      roomID,
		"room_version": roomVersion,
	}).Info("Sent event to roomserver")
	timeToSubmitEvent := time.Since(startedSubmittingEvent)

	res := util.JSONResponse{
		Code: http.StatusOK,
		JSON: sendEventResponse{e.EventID()},
	}
	// Add response to transactionsCache
	if txnID != nil {
		txnCache.AddTransaction(device.AccessToken, *txnID, req.URL, &res)
	}

	// Take a note of how long it took to generate the event vs submit
	// it to the roomserver.
	sendEventDuration.With(prometheus.Labels{"action": "build"}).Observe(float64(timeToGenerateEvent.Milliseconds()))
	sendEventDuration.With(prometheus.Labels{"action": "submit"}).Observe(float64(timeToSubmitEvent.Milliseconds()))

	return res
}

func (r sendServerNoticeRequest) valid() (ok bool) {
	if r.UserID == "" {
		return false
	}
	if r.Content.MsgType == "" || r.Content.Body == "" {
		return false
	}
	return true
}

// getSenderDevice creates a user account to be used when sending server notices.
// It returns an userapi.Device, which is used for building the event
func getSenderDevice(
	ctx context.Context,
	rsAPI api.ClientRoomserverAPI,
	userAPI userapi.ClientUserAPI,
	cfg *config.ClientAPI,
) (*userapi.Device, error) {
	var accRes userapi.PerformAccountCreationResponse
	// create account if it doesn't exist
	err := userAPI.PerformAccountCreation(ctx, &userapi.PerformAccountCreationRequest{
		AccountType: userapi.AccountTypeUser,
		Localpart:   cfg.Matrix.ServerNotices.LocalPart,
		ServerName:  cfg.Matrix.ServerName,
		OnConflict:  userapi.ConflictUpdate,
	}, &accRes)
	if err != nil {
		return nil, err
	}

	// Set the avatarurl for the user
	profile, avatarChanged, err := userAPI.SetAvatarURL(ctx,
		cfg.Matrix.ServerNotices.LocalPart,
		cfg.Matrix.ServerName,
		cfg.Matrix.ServerNotices.AvatarURL,
	)
	if err != nil {
		util.GetLogger(ctx).WithError(err).Error("userAPI.SetAvatarURL failed")
		return nil, err
	}

	// Set the displayname for the user
	_, displayNameChanged, err := userAPI.SetDisplayName(ctx,
		cfg.Matrix.ServerNotices.LocalPart,
		cfg.Matrix.ServerName,
		cfg.Matrix.ServerNotices.DisplayName,
	)
	if err != nil {
		util.GetLogger(ctx).WithError(err).Error("userAPI.SetDisplayName failed")
		return nil, err
	}

	if displayNameChanged {
		profile.DisplayName = cfg.Matrix.ServerNotices.DisplayName
	}

	// Check if we got existing devices
	deviceRes := &userapi.QueryDevicesResponse{}
	err = userAPI.QueryDevices(ctx, &userapi.QueryDevicesRequest{
		UserID: accRes.Account.UserID,
	}, deviceRes)
	if err != nil {
		return nil, err
	}

	// We've got an existing account, return the first device of it
	if len(deviceRes.Devices) > 0 {
		// If there were changes to the profile, create a new membership event
		if displayNameChanged || avatarChanged {
			_, err = updateProfile(ctx, rsAPI, &deviceRes.Devices[0], profile, accRes.Account.UserID, time.Now())
			if err != nil {
				return nil, err
			}
		}
		return &deviceRes.Devices[0], nil
	}

	// create an AccessToken
	token, err := tokens.GenerateLoginToken(tokens.TokenOptions{
		ServerPrivateKey: cfg.Matrix.PrivateKey.Seed(),
		ServerName:       string(cfg.Matrix.ServerName),
		UserID:           accRes.Account.UserID,
	})
	if err != nil {
		return nil, err
	}

	// create a new device, if we didn't find any
	var devRes userapi.PerformDeviceCreationResponse
	err = userAPI.PerformDeviceCreation(ctx, &userapi.PerformDeviceCreationRequest{
		Localpart:          cfg.Matrix.ServerNotices.LocalPart,
		ServerName:         cfg.Matrix.ServerName,
		DeviceDisplayName:  &cfg.Matrix.ServerNotices.LocalPart,
		AccessToken:        token,
		NoDeviceListUpdate: true,
	}, &devRes)

	if err != nil {
		return nil, err
	}
	return devRes.Device, nil
}
