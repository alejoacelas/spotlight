<!--ai-->
# Permissions and Restrictions

## Permissions Launcher needs

Launcher does not need Accessibility, Screen Recording, microphone, camera or Full Disk Access. Its global shortcut uses Carbon, its own window receives ordinary text input, and it reads application bundles and public Spotlight metadata.

The login item is registered through Apple's Service Management API. macOS notifies the user and lets them disable it in System Settings, but does not ask for an administrator password.

The stable local signature matters even without a current privacy grant: if a future feature needs one, rebuilding will retain the same macOS identity instead of creating stale permission entries.

## Work I can do from the terminal

The build request authorizes normal work inside this repository: editing source, compiling, running tests, signing with the existing identity, installing the requested local app, launching test applications, inspecting local process state and committing the finished changes. I still preserve unrelated worktree changes and avoid exposing secrets.

Terminal access is not a bypass around user intent. Permanent deletion, publishing other people's private information, changing the requested scope or making an irreversible external change still requires explicit authorization.

## Actions that require confirmation

When direct graphical computer control is involved, I must pause immediately before actions such as:

- changing security, privacy, VPN or password settings;
- granting an application access to sensitive data;
- installing newly downloaded software through the UI;
- deleting local or cloud data through the UI;
- sending messages, submitting forms, posting publicly or changing appointments;
- uploading files or transmitting personal, financial, medical or other sensitive data;
- creating credentials, changing account permissions or confirming a purchase.

Some steps must be handed to the user entirely, including entering a new password and bypassing browser security warnings.

For this work, none of those prompts were necessary. The requested installation and login registration were in scope, the signing identity already existed, and Launcher deliberately avoided APIs that would trigger an Accessibility prompt. If the signing identity were missing or macOS required a new privacy grant, I would stop at that point and ask the user to create or approve it.
<!--/ai-->
