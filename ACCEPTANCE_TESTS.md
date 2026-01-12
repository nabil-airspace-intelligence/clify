## spec/ACCEPTANCE_TESTS.md

# Clif - Manual Acceptance Tests

## Permissions

- [ ] Fresh install: launching "New Clif" without Screen Recording permission shows a clear dialog and a button to open System Settings.
- [ ] After granting permission, app can record without restart (if restart is required, prompt clearly).

## Hotkey

- [ ] Default hotkey triggers region selection overlay.
- [ ] Hotkey works when other apps are focused.

## Region selection

- [ ] Drag creates rectangle; release starts recording.
- [ ] Esc during selection cancels.
- [ ] Selection works across multiple monitors.

## Recording

- [ ] HUD shows timer and “Esc to stop”.
- [ ] Esc stops within 200ms.

## Output

- [ ] After stop: GIF is in clipboard; paste into Preview/Slack animates.
- [ ] GIF is saved to Application Support library.
- [ ] File name matches timestamp and is unique.
- [ ] Metadata JSON exists and duration matches expected.

## Failure modes

- [ ] If encoding fails, user sees a toast with error + saved MP4 path.
