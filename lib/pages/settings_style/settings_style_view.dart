import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';

import 'package:rechainonline/config/setting_keys.dart';
import 'package:rechainonline/config/themes.dart';
import 'package:rechainonline/utils/account_config.dart';
import 'package:rechainonline/widgets/avatar.dart';
import 'package:rechainonline/widgets/layouts/max_width_body.dart';
import 'package:rechainonline/widgets/matrix.dart';
import 'package:rechainonline/widgets/mxc_image.dart';
import '../../config/app_config.dart';
import '../../widgets/settings_switch_list_tile.dart';
import 'settings_style.dart';

class SettingsStyleView extends StatelessWidget {
  final SettingsStyleController controller;

  const SettingsStyleView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const colorPickerSize = 32.0;
    final client = Matrix.of(context).client;
    return Scaffold(
      appBar: AppBar(
        leading: const Center(child: BackButton()),
        title: Text(L10n.of(context)!.changeTheme),
      ),
      backgroundColor: theme.colorScheme.surface,
      body: MaxWidthBody(
        child: Column(
          children: [
            ListTile(
              title: Text(
                L10n.of(context)!.setColorTheme,
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: colorPickerSize + 24,
              child: ListView(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                children: SettingsStyleController.customColors
                    .map(
                      (color) => Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(colorPickerSize),
                          onTap: () => controller.setChatColor(color),
                          child: color == null
                              ? Material(
                                  elevation: 6,
                                  shadowColor: AppConfig.colorSchemeSeed,
                                  borderRadius:
                                      BorderRadius.circular(colorPickerSize),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        colorPickerSize,
                                      ),
                                      gradient: rechainonlineThemes.backgroundGradient(
                                        context,
                                        255,
                                      ),
                                    ),
                                    child: SizedBox(
                                      height: colorPickerSize,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (controller.currentColor ==
                                                  null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    right: 8.0,
                                                  ),
                                                  child: Icon(
                                                    Icons.check,
                                                    size: 16,
                                                    color: theme
                                                        .colorScheme.onSurface,
                                                  ),
                                                ),
                                              Text(
                                                L10n.of(context)!.systemTheme,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: theme
                                                      .colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Material(
                                  color: color,
                                  elevation: 6,
                                  borderRadius:
                                      BorderRadius.circular(colorPickerSize),
                                  child: SizedBox(
                                    width: colorPickerSize,
                                    height: colorPickerSize,
                                    child: controller.currentColor == color
                                        ? const Center(
                                            child: Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              color: theme.dividerColor,
            ),
            ListTile(
              title: Text(
                L10n.of(context)!.setTheme,
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            RadioListTile<ThemeMode>(
              groupValue: controller.currentTheme,
              value: ThemeMode.system,
              title: Text(L10n.of(context)!.systemTheme),
              onChanged: controller.switchTheme,
            ),
            RadioListTile<ThemeMode>(
              groupValue: controller.currentTheme,
              value: ThemeMode.light,
              title: Text(L10n.of(context)!.lightTheme),
              onChanged: controller.switchTheme,
            ),
            RadioListTile<ThemeMode>(
              groupValue: controller.currentTheme,
              value: ThemeMode.dark,
              title: Text(L10n.of(context)!.darkTheme),
              onChanged: controller.switchTheme,
            ),
            Divider(
              color: theme.dividerColor,
            ),
            ListTile(
              title: Text(
                L10n.of(context)!.overview,
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SettingsSwitchListTile.adaptive(
              title: L10n.of(context)!.presencesToggle,
              onChanged: (b) => AppConfig.showPresences = b,
              storeKey: SettingKeys.showPresences,
              defaultValue: AppConfig.showPresences,
            ),
            SettingsSwitchListTile.adaptive(
              title: L10n.of(context)!.separateChatTypes,
              onChanged: (b) => AppConfig.separateChatTypes = b,
              storeKey: SettingKeys.separateChatTypes,
              defaultValue: AppConfig.separateChatTypes,
            ),
            Divider(
              color: theme.dividerColor,
            ),
            ListTile(
              title: Text(
                L10n.of(context)!.messagesStyle,
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            StreamBuilder(
              stream: client.onSync.stream.where(
                (syncUpdate) =>
                    syncUpdate.accountData?.any(
                      (accountData) =>
                          accountData.type ==
                          ApplicationAccountConfigExtension.accountDataKey,
                    ) ??
                    false,
              ),
              builder: (context, snapshot) {
                final accountConfig = client.applicationAccountConfig;
                final wallpaperOpacity = accountConfig.wallpaperOpacity ?? 1;
                final wallpaperOpacityIsDefault = wallpaperOpacity == 1;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: rechainonlineThemes.animationDuration,
                      curve: rechainonlineThemes.animationCurve,
                      alignment: Alignment.centerLeft,
                      decoration: const BoxDecoration(),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        children: [
                          if (accountConfig.wallpaperUrl != null)
                            Opacity(
                              opacity: wallpaperOpacity,
                              child: MxcImage(
                                uri: accountConfig.wallpaperUrl,
                                fit: BoxFit.cover,
                                isThumbnail: true,
                                width: rechainonlineThemes.columnWidth * 2,
                                height: 156,
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.only(
                              left: 12 + 12 + Avatar.defaultSize,
                              right: 12,
                              top: accountConfig.wallpaperUrl == null ? 0 : 12,
                              bottom: 12,
                            ),
                            child: Material(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(
                                AppConfig.borderRadius,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontSize: AppConfig.messageFontSize *
                                        AppConfig.fontSizeFactor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      title: Text(L10n.of(context)!.wallpaper),
                      leading: const Icon(Icons.photo_outlined),
                      trailing: accountConfig.wallpaperUrl == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outlined),
                              color: theme.colorScheme.error,
                              onPressed: controller.deleteChatWallpaper,
                            ),
                      onTap: controller.setWallpaper,
                    ),
                    AnimatedSize(
                      duration: rechainonlineThemes.animationDuration,
                      curve: rechainonlineThemes.animationCurve,
                      child: accountConfig.wallpaperUrl != null
                          ? SwitchListTile.adaptive(
                              title: Text(L10n.of(context)!.transparent),
                              secondary: const Icon(Icons.blur_linear_outlined),
                              value: !wallpaperOpacityIsDefault,
                              onChanged: (_) =>
                                  controller.setChatWallpaperOpacity(
                                wallpaperOpacityIsDefault ? 0.4 : 1,
                              ),
                            )
                          : null,
                    ),
                  ],
                );
              },
            ),
            ListTile(
              title: Text(L10n.of(context)!.fontSize),
              trailing: Text('× ${AppConfig.fontSizeFactor}'),
            ),
            Slider.adaptive(
              min: 0.5,
              max: 2.5,
              divisions: 20,
              value: AppConfig.fontSizeFactor,
              semanticFormatterCallback: (d) => d.toString(),
              onChanged: controller.changeFontSizeFactor,
            ),
          ],
        ),
      ),
    );
  }
}
