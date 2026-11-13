# Lynk car status widget extension

An iOS WidgetKit extension for Home Screen and Lock Screen. It reads a small
whitelisted status snapshot written by its containing app into a shared App Group.
It makes no network requests, contains no account credentials and sends no car commands.

The widget displays battery percentage, combined range, interior/exterior temperatures
and the original vehicle-status timestamp. Medium widgets also show electric range
and fuel amount. Tapping opens the containing app through its dedicated URL scheme.

The original IPA, car data and app credentials are not needed for this build.
The resulting unsigned `.appex` is integrated with the IPA locally and subsequently
signed with the owner's installer. App Group grants must match between app and extension.

Build with the included GitHub Actions workflow, or generate the project using
XcodeGen and build the LynkCarWidgets scheme for a generic iOS device in Xcode.
The bridge from the containing app and final IPA packaging are maintained locally.

The first build compiled successfully and the widgets registered on an iPhone.
The current revision fixes shared-container selection after the containing app
is re-signed, and tests the reader with an overridden legacy bundle identifier.
It also improves text contrast on the Home Screen. Data display with this revision
still needs verification on the owner's iPhone.
