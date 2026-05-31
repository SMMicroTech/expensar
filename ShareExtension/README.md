Share Extension integration (manual steps)

This folder contains a ready-to-use Share Extension source and entitlements to accept images and hand them off to the main app via the `expensar://` URL scheme.

Files created:
- `ShareExtension/Info.plist` — extension Info.plist
- `ShareExtension/ShareViewController.swift` — minimal share extension principal class
- `ShareExtension/ShareExtension.entitlements` — entitlements with App Group
- `Entitlements/App.entitlements` — app entitlements with App Group

Manual steps to add the Share Extension target in Xcode:

1. Open the workspace in Xcode.
2. Select the project, click the + button at the bottom of the Targets list and choose "Share Extension" → "Share Extension" (iOS).
3. When Xcode prompts for a target name, use `ExpensarShare`.
4. Replace the generated `Info.plist` and `ShareViewController` code with the versions in `ShareExtension/` (or copy these files into the new target group).
5. Add the `ShareExtension/ShareExtension.entitlements` file to the extension target (set in Build Settings → Code Signing Entitlements).
6. Add the `Entitlements/App.entitlements` file to the main app target (Build Settings → Code Signing Entitlements).
7. In both targets' Signing & Capabilities, enable **App Groups** and add `group.com.netdots.expensar`.
8. Ensure both targets have the same App Group in the entitlements and Signing & Capabilities.
9. Build and run the app + extension. In the simulator Photos app, choose a photo → Share → More → enable "Expensar Share" (it will appear after installing the extension). Use the extension to share; it will write the image to the App Group container and open the main app's `expensar://` URL with `imageFileURL=` pointing to the file.

If you want, I can add the new target entries directly to `project.pbxproj` (I can do this safely but it's involved); say "add target to project" and I'll update the Xcode project file automatically.