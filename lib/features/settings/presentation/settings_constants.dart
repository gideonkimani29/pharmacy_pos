import '../domain/entities/app_settings.dart';
import '../domain/entities/app_user.dart';

abstract final class SettingsStrings {
  static const String title = 'Settings';
  static const String subtitle = 'Pharmacy details, tax, receipts and who can sign in';

  static const String navPharmacy = 'Pharmacy';
  static const String navSales = 'Sales & tax';
  static const String navReceipts = 'Receipts & printer';
  static const String navUsers = 'Users & roles';

  static const String save = 'Save changes';
  static const String saving = 'Saving...';
  static const String discard = 'Discard';
  static const String cancel = 'Cancel';
  static const String saved = 'Settings saved.';
  static const String unsavedChanges = 'You have unsaved changes.';
  static const String loadFailed = 'Could not load settings';
  static const String retry = 'Try again';

  // Pharmacy
  static const String pharmacyTitle = 'Pharmacy details';
  static const String pharmacyHint = 'Shown on receipts and reports.';
  static const String fieldName = 'Pharmacy name';
  static const String fieldBranch = 'Branch';
  static const String fieldAddress = 'Address';
  static const String fieldPhone = 'Phone number';
  static const String fieldEmail = 'Email';
  static const String fieldTaxPin = 'KRA PIN';
  static const String taxPinHint = 'Format: A123456789B';
  static const String fieldLicence = 'Pharmacy licence number';
  static const String licenceHint = 'Your Pharmacy and Poisons Board registration.';

  // Sales and tax
  static const String salesTitle = 'Sales and tax';
  static const String salesHint = 'Rules the till follows when it sells.';
  static const String currencyLabel = 'Currency';
  static const String currencyValue = 'Kenya Shilling (KES)';
  static const String fieldTaxRate = 'Tax rate';
  static const String taxRateHint =
      'Most medicines are VAT-exempt in Kenya. Use 0 if all your products are exempt, and confirm the rate with your accountant.';
  static const String fieldMaxDiscount = 'Largest discount a cashier can give';
  static const String discountHint = 'Percent of the sale. Bigger discounts need a pharmacist or admin.';
  static const String fieldAllowCredit = 'Allow credit sales';
  static const String creditHint = 'When off, the Credit sale option is hidden at checkout.';
  static const String rxRule =
      'Prescription-only medicines always need a pharmacist check at checkout. This cannot be turned off.';
  static const String notYetApplied =
      'The checkout still uses the built-in tax rate until it reads these settings from the server.';

  // Receipts and printer
  static const String receiptsTitle = 'Receipts and printer';
  static const String receiptsHint = 'How receipts look and where they print.';
  static const String fieldPrinter = 'Printer connection';
  static const String fieldPaper = 'Paper width';
  static const String fieldAutoPrint = 'Print a receipt after every sale';
  static const String fieldCopies = 'Copies';
  static const String fieldPrintDetails = 'Print pharmacy details on receipts';
  static const String fieldFooter = 'Receipt footer message';
  static const String footerHint = 'For example: Thank you. Get well soon.';
  static const String printerNote = 'Printing is not built yet. These choices are saved for when it is.';

  // Users
  static const String usersTitle = 'Users and roles';
  static const String usersHint = 'Everyone who can sign in, and what they are allowed to do.';
  static const String addUser = 'Add user';
  static const String editUser = 'Edit user';
  static const String colUser = 'User';
  static const String colRole = 'Role';
  static const String colActive = 'Active';
  static const String colLastSignIn = 'Last sign-in';
  static const String colEdit = 'Edit';
  static const String never = 'Never';
  static const String editTooltip = 'Edit user';
  static const String activeTooltip = 'Inactive users cannot sign in';
  static const String fieldUserName = 'Full name';
  static const String fieldUserEmail = 'Email (used to sign in)';
  static const String fieldUserPhone = 'Phone (optional)';
  static const String fieldUserRole = 'Role';
  static const String inviteNote =
      'A new user gets an email to set their own password. Passwords are never entered or stored in this app.';
  static const String rolesTitle = 'What each role can do';
  static const String noUsers = 'No users yet.';
  static String userSaved(String name) => '$name saved.';
  static String userActivated(String name) => '$name can sign in again.';
  static String userDeactivated(String name) => '$name can no longer sign in.';

  static String printerLabel(PrinterConnection connection) => switch (connection) {
        PrinterConnection.none => 'No printer',
        PrinterConnection.usb => 'USB',
        PrinterConnection.bluetooth => 'Bluetooth',
      };

  static String paperLabel(PaperWidth width) => switch (width) {
        PaperWidth.mm58 => '58 mm',
        PaperWidth.mm80 => '80 mm (standard)',
      };

  static String roleLabel(UserRole role) => switch (role) {
        UserRole.admin => 'Admin',
        UserRole.pharmacist => 'Pharmacist',
        UserRole.cashier => 'Cashier',
      };

  static String roleSummary(UserRole role) => switch (role) {
        UserRole.admin =>
          'Everything, including settings, users, costs, profit and stock adjustments.',
        UserRole.pharmacist =>
          'Sells, checks prescriptions, gives larger discounts, and manages medicines, purchases, stock, customers and reports.',
        UserRole.cashier =>
          'Sells and takes payments. Cannot see costs or profit, change prices, or adjust stock.',
      };
}

abstract final class SettingsLayout {
  static const double navWidth = 240;
  static const double compactBreakpoint = 900;
  static const double formMaxWidth = 820;
  static const double halfFieldWidth = 360;
  static const double smallFieldWidth = 200;
  static const double userDialogWidth = 480;
  static const double roleColumnWidth = 130;
  static const double statusColumnWidth = 90;
  static const double signInColumnWidth = 140;
  static const double editColumnWidth = 70;
  static const double inactiveOpacity = 0.55;
  static const int userNameFlex = 5;
  static const int footerLines = 2;
}
