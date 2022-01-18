/**
 * @copyright Copyright (c) 2022 Aleksandra Lazarevic <aleksandra@nextcloud.com>
 *
 * @author Aleksandra Lazarevic <aleksandra@nextcloud.com>
 *
 * @license GNU GPL version 3 or any later version
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

import UIKit
import NCCommunication
import SafariServices

enum SettingsSection: Int {
    case kSettingsSectionUser = 0
    case kSettingsSectionUserStatus
    case kSettingsSectionAccounts
    case kSettingsSectionConfiguration
    case kSettingsSectionAbout
}

enum ConfigurationSectionOption: Int {
    case kConfigurationSectionOptionVideo = 0
    case kConfigurationSectionOptionBrowser
    case kConfigurationSectionOptionReadStatus
    case kConfigurationSectionOptionContactsSync
}

enum AboutSection: Int {
    case kAboutSectionPrivacy = 0
    case kAboutSectionSourceCode
    case kAboutSectionNumber
}

let kPhoneTextFieldTag = 99

class SettingsTableViewController: UITableViewController, UITextFieldDelegate {

    var activeUserStatus: NCUserStatus?
    var readStatusSwitch: UISwitch?
    var contactSyncSwitch: UISwitch?
    var setPhoneAction: UIAlertAction?
    var phoneUtil: NBPhoneNumberUtil?

    @IBOutlet weak var cancelButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("Settings", comment: "")
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NCAppBranding.themeTextColor()]
        self.navigationController?.navigationBar.tintColor = NCAppBranding.themeColor()
        self.tabBarController?.tabBar.tintColor = NCAppBranding.themeColor()
        self.cancelButton.tintColor = NCAppBranding.themeTextColor()

        phoneUtil = NBPhoneNumberUtil()

        contactSyncSwitch = UISwitch(frame: .zero)
        contactSyncSwitch?.addTarget(self, action: #selector(contactSyncValueChanged(_:)), for: .valueChanged)

        readStatusSwitch = UISwitch(frame: .zero)
        readStatusSwitch?.addTarget(self, action: #selector(readStatusValueChanged(_:)), for: .valueChanged)

        if #available(iOS 13.0, *) {
            let themeColor: UIColor = NCAppBranding.themeColor()
            let themeTextColor: UIColor = NCAppBranding.themeTextColor()

            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.titleTextAttributes = [.foregroundColor: themeTextColor]
            appearance.backgroundColor = themeColor
            self.navigationItem.standardAppearance = appearance
            self.navigationItem.compactAppearance = appearance
            self.navigationItem.scrollEdgeAppearance = appearance
        }

        tableView.register(UINib(nibName: kUserSettingsTableCellNibName, bundle: nil), forCellReuseIdentifier: kUserSettingsCellIdentifier)

        tableView.register(UINib(nibName: kAccountTableViewCellNibName, bundle: nil), forCellReuseIdentifier: kAccountCellIdentifier)

        NotificationCenter.default.addObserver(self, selector: #selector(appStateHasChanged(notification:)), name: NSNotification.Name.NCAppStateHasChanged, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(contactsHaveBeenUpdated(notification:)), name: NSNotification.Name.NCContactsManagerContactsUpdated, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(contactsAccessHasBeenUpdated(notification:)), name: NSNotification.Name.NCContactsManagerContactsAccessUpdated, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        self.adaptInterfaceForAppState(appState: NCConnectionController.sharedInstance().appState)
        tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    func getSettingsSections() -> [Int] {
        var sections = [Int]()

        // Active user sections
        sections.append(SettingsSection.kSettingsSectionUser.rawValue)
        // User Status section
        let activeAccount: TalkAccount = NCDatabaseManager.sharedInstance().activeAccount()
        let serverCapabilities = NCDatabaseManager.sharedInstance().serverCapabilities(forAccountId: activeAccount.accountId)

        if serverCapabilities.userStatus {
            sections.append(SettingsSection.kSettingsSectionUserStatus.rawValue)
        }
        // Accounts section
        if !NCDatabaseManager.sharedInstance().inactiveAccounts().isEmpty {
            sections.append(SettingsSection.kSettingsSectionAccounts.rawValue)
        }
        // Configuration section
        sections.append(SettingsSection.kSettingsSectionConfiguration.rawValue)
        // About section
        sections.append(SettingsSection.kSettingsSectionAbout.rawValue)
        return sections
    }

    func getConfigurationSectionOptions() -> [Int] {
        var options = [Int]()
        // Video quality
        options.append(ConfigurationSectionOption.kConfigurationSectionOptionVideo.rawValue)
        // Open links in
        if NCSettingsController.sharedInstance().supportedBrowsers.count > 1 {
            options.append(ConfigurationSectionOption.kConfigurationSectionOptionBrowser.rawValue)
        }
        // Read status privacy setting
        if NCDatabaseManager.sharedInstance().serverHasTalkCapability(kCapabilityChatReadStatus) {
            options.append(ConfigurationSectionOption.kConfigurationSectionOptionReadStatus.rawValue)
        }
        // Contacts sync
        if NCDatabaseManager.sharedInstance().serverHasTalkCapability(kCapabilityPhonebookSearch) {
            options.append(ConfigurationSectionOption.kConfigurationSectionOptionContactsSync.rawValue)
        }
        return options
    }

    func getSectionForSettingsSection(section: SettingsSection) -> Int {
        let sectionNumber = getSettingsSections().firstIndex(of: section.rawValue)
        if NSNotFound != sectionNumber {
            return sectionNumber!
        }
        return 0
    }

    func getIndexPathForConfigurationOption(option: ConfigurationSectionOption) -> IndexPath {
        let section: Int = getSectionForSettingsSection(section: SettingsSection.kSettingsSectionConfiguration)
        var optionIndexPath: IndexPath = IndexPath(row: 0, section: section)

        let optionRow = getConfigurationSectionOptions().firstIndex(of: option.rawValue)

        if NSNotFound != optionRow {
            optionIndexPath = IndexPath(row: optionRow!, section: section)
        }
        return optionIndexPath
    }

    // MARK: User Profile

    func refreshUserProfile() {
        NCSettingsController.sharedInstance().getUserProfile { _ in
            self.tableView.reloadData()
        }
        self.getActiveUserStatus()
    }

    func getActiveUserStatus() {
        let activeAccount = NCDatabaseManager.sharedInstance().activeAccount()
        NCAPIController.sharedInstance().getUserStatus(for: activeAccount) { userStatus, error in
            if error == nil && userStatus != nil {
                self.activeUserStatus = NCUserStatus(dictionary: userStatus!)
                self.tableView.reloadData()
            }
        }
    }

    // MARK: Notifications

    @objc func appStateHasChanged(notification: NSNotification) {
        let appState = notification.userInfo!["appState"]
        self.adaptInterfaceForAppState(appState: appState as? AppState ?? kAppStateReady)
    }

    @objc func contactsHaveBeenUpdated(notification: NSNotification) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    @objc func contactsAccessHasBeenUpdated(notification: NSNotification) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    // MARK: User Interface

    func adaptInterfaceForAppState(appState: AppState) {
        switch appState {
        case kAppStateReady:
            refreshUserProfile()
        default:
            break
        }
    }

    // MARK: Profile actions

    func userProfilePressed() {
        let activeAccount = NCDatabaseManager.sharedInstance().activeAccount()
        let userProfileVC = UserProfileViewController(account: activeAccount)
        self.navigationController!.pushViewController(userProfileVC, animated: true)
    }

    // MARK: User Status

    func presetnUserStatusOptions() {
        let viewController = UserStatusTableViewController(userStatus: activeUserStatus!)
        self.navigationController!.pushViewController(viewController, animated: true)
    }

    // MARK: User phone number

    func checkUserPhoneNumber() {
        NCSettingsController.sharedInstance().getUserProfile { _ in
            let activeAccount = NCDatabaseManager.sharedInstance().activeAccount()
            if activeAccount.phone.isEmpty {
                self.presentSetPhoneNumberDialog()
            }
        }
    }

    func presentSetPhoneNumberDialog() {
        let alertTitle = NSLocalizedString("Phone number", comment: "")
        let alertMessage = NSLocalizedString("You can set your phone number so other users will be able to find you", comment: "")
        let setPhoneNumberDialog = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)

        setPhoneNumberDialog.addTextField { [self] textField in
            let location = NSLocale.current.regionCode
            textField.text = "+\(self.phoneUtil?.getCountryCode(forRegion: location) ?? 0)"
            do {
                let exampleNumber: NBPhoneNumber =  try phoneUtil!.getExampleNumber(location)
                textField.placeholder = try phoneUtil?.format(exampleNumber, numberFormat: NBEPhoneNumberFormat.INTERNATIONAL)
            } catch {
                print("Error with phone number format...")
            }
            textField.keyboardType = .phonePad
            textField.delegate = self
            textField.tag = kPhoneTextFieldTag
        }
        setPhoneAction = UIAlertAction(title: NSLocalizedString("Set", comment: ""), style: .default, handler: { _ in
            let phoneNumber = setPhoneNumberDialog.textFields?[0].text

            NCAPIController.sharedInstance().setUserProfileField(kUserProfilePhone, withValue: phoneNumber, for: NCDatabaseManager.sharedInstance().activeAccount()) { error, _ in
                if error != nil {
                    self.presentPhoneNumberErrorDialog(phoneNumber: phoneNumber!)
                    print("Error setting phone number ", error ?? "")
                } else {
                    let alert = UIAlertController(title: NSLocalizedString("Phone number set successfully", comment: ""), message: "", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                }
                self.refreshUserProfile()
            }
        })

        setPhoneAction!.isEnabled = false
        setPhoneNumberDialog.addAction(setPhoneAction!)

        let cancelAction = UIAlertAction(title: NSLocalizedString("Skip", comment: ""), style: .default) { _ in
            self.refreshUserProfile()
        }
        setPhoneNumberDialog.addAction(cancelAction)
        self.present(setPhoneNumberDialog, animated: true, completion: nil)
    }

    func presentPhoneNumberErrorDialog(phoneNumber: String) {
        var failedPhoneNumberDialog: UIAlertController?
        var failedPhoneNumber: NBPhoneNumber?
        do {
            failedPhoneNumber = try phoneUtil!.parse(phoneNumber, defaultRegion: nil)
        } catch {
            print("Error...")
        }

        do {
            let alertTitle = NSLocalizedString("Could not set phone number", comment: "")
            let alertMessage = (NSLocalizedString("An error occurred while setting \(failedPhoneNumber) as phone number", comment: ""))
            failedPhoneNumberDialog = UIAlertController(
                   title: alertTitle,
                   message: alertMessage + "\(try phoneUtil!.format(failedPhoneNumber, numberFormat: NBEPhoneNumberFormat.INTERNATIONAL))",
                   preferredStyle: .alert)
            let retryAction = UIAlertAction(title: NSLocalizedString("Retry", comment: ""), style: .default, handler: { [self] _ in presentSetPhoneNumberDialog()
            })
            failedPhoneNumberDialog!.addAction(retryAction)

        } catch {
            print("Error...")
        }

        let retryAction = UIAlertAction(title: NSLocalizedString("Retry", comment: ""), style: .default) { _ in
            self.presentSetPhoneNumberDialog()
        }
        failedPhoneNumberDialog!.addAction(retryAction)

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .default, handler: nil)
        failedPhoneNumberDialog!.addAction(cancelAction)

        self.present(failedPhoneNumberDialog!, animated: true, completion: nil)

    }

    // MARK: UITextField delegate

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField.tag == kPhoneTextFieldTag {
            let inputPhoneNumber = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
            var phoneNumber: NBPhoneNumber?
            do {
                phoneNumber = try phoneUtil!.parse(inputPhoneNumber, defaultRegion: nil)
            } catch {
            }
            setPhoneAction!.isEnabled = phoneUtil!.isValidNumber(phoneNumber)
        }
        return true
    }

    // MARK: Configuration

    func presentVideoResoultionsSelector() {
        let videoConfIndexPath = self.getIndexPathForConfigurationOption(option: ConfigurationSectionOption.kConfigurationSectionOptionVideo)
        let videoResolutions = NCSettingsController.sharedInstance().videoSettingsModel.availableVideoResolutions()
        let storedResolution = NCSettingsController.sharedInstance().videoSettingsModel.currentVideoResolutionSettingFromStore()

        let optionsActionSheet = UIAlertController(title: NSLocalizedString("Video quality", comment: ""), message: nil, preferredStyle: .actionSheet)

        for resolution in videoResolutions {
            let readableResolution = NCSettingsController.sharedInstance().videoSettingsModel.readableResolution(resolution)
            let isStoredResolution = resolution == storedResolution
            let action = UIAlertAction(title: readableResolution, style: .default) { _ in
                NCSettingsController.sharedInstance().videoSettingsModel.storeVideoResolutionSetting(resolution)
                self.tableView.beginUpdates()

                self.tableView.reloadRows(at: [videoConfIndexPath], with: .none)

                self.tableView.endUpdates()
            }

            if isStoredResolution {
                action.setValue(UIImage(named: "checkmark")?.withRenderingMode(_:.alwaysOriginal), forKey: "image")
            }
            optionsActionSheet.addAction(action)
        }

        optionsActionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))

        // Presentation on iPads
        optionsActionSheet.popoverPresentationController?.sourceView = self.tableView
        optionsActionSheet.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: videoConfIndexPath)

        self.present(optionsActionSheet, animated: true, completion: nil)
    }

    func presentBrowserSelector() {
        let browserConfIndexPath = self.getIndexPathForConfigurationOption(option: ConfigurationSectionOption.kConfigurationSectionOptionBrowser)
        let supportedBrowsers = NCSettingsController.sharedInstance().supportedBrowsers!
        let defaultBrowser = NCUserDefaults.defaultBrowser()

        let optionsActionSheet = UIAlertController(title: NSLocalizedString("Open links in", comment: ""), message: nil, preferredStyle: .actionSheet)

        for browser in supportedBrowsers {
            var isDefaultBrowser = false
            if let browser = browser as? String {
                isDefaultBrowser = browser == defaultBrowser
            }
            let action = UIAlertAction(title: browser as? String, style: .default) { _ in
                NCUserDefaults.setDefaultBrowser((browser as? String)!)
                self.tableView.reloadData()
            }
            if isDefaultBrowser {
                action.setValue(UIImage(named: "checkmark")?.withRenderingMode(_:.alwaysOriginal), forKey: "image")
            }
            optionsActionSheet.addAction(action)
        }
        optionsActionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))

        // Presentation on iPads
        optionsActionSheet.popoverPresentationController?.sourceView = self.tableView
        optionsActionSheet.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: browserConfIndexPath)

        self.present(optionsActionSheet, animated: true, completion: nil)
    }

    @objc func contactSyncValueChanged(_ sender: Any?) {
        NCSettingsController.sharedInstance().setContactSync(contactSyncSwitch!.isOn)

        if contactSyncSwitch!.isOn {
            if !NCContactsManager.sharedInstance().isContactAccessDetermined() {
                NCContactsManager.sharedInstance().requestContactsAccess()
            } else if NCContactsManager.sharedInstance().isContactAccessAuthorized() {
                self.checkUserPhoneNumber()
                NCContactsManager.sharedInstance().searchInServer(forAddressBookContacts: true)
            }
        } else {
            NCContactsManager.sharedInstance().removeStoredContacts()
        }
        // Reload to update configuration section footer
        self.tableView.reloadData()
    }

    @objc func readStatusValueChanged(_ sender: Any?) {
        readStatusSwitch!.isEnabled = false

        NCAPIController.sharedInstance().setReadStatusPrivacySettingEnabled(!readStatusSwitch!.isOn, for: NCDatabaseManager.sharedInstance().activeAccount()) { error in
            if error == nil {
                NCSettingsController.sharedInstance().getCapabilitiesWithCompletionBlock { error in
                    if error == nil {
                        self.readStatusSwitch?.isEnabled = true
                        self.tableView.reloadData()
                    } else {
                        self.showReadStatusModificationError()
                    }
                }
            } else {
                self.showReadStatusModificationError()
            }
        }
    }

    func showReadStatusModificationError() {
        readStatusSwitch?.isOn = true
        let errorDialog = UIAlertController(
            title: NSLocalizedString("An error occurred changing read status setting", comment: ""),
            message: nil,
            preferredStyle: .alert)
        let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil)
        errorDialog.addAction(okAction)
        self.present(errorDialog, animated: true, completion: nil)
    }

    // MARK: Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return getSettingsSections().count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sections = getSettingsSections()
        let settingsSection = (sections[section] as? Int)!

        switch settingsSection {
        case SettingsSection.kSettingsSectionUserStatus.rawValue:
            return 1
        case SettingsSection.kSettingsSectionConfiguration.rawValue:
            return getConfigurationSectionOptions().count
        case SettingsSection.kSettingsSectionAbout.rawValue:
            return AboutSection.kAboutSectionNumber.rawValue
        case SettingsSection.kSettingsSectionAccounts.rawValue:
            return NCDatabaseManager.sharedInstance().inactiveAccounts().count
        default:
            break
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sections = getSettingsSections()
        let currentSection = (sections[indexPath.section] as? Int)!
        if currentSection == SettingsSection.kSettingsSectionUser.rawValue {
            return 100
        }
        return 48
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sections = getSettingsSections()
        let settignsSection = (sections[section] as? Int)!

        switch settignsSection {
        case SettingsSection.kSettingsSectionUserStatus.rawValue:
            return NSLocalizedString("Status", comment: "")
        case SettingsSection.kSettingsSectionAccounts.rawValue:
            return NSLocalizedString("Accounts", comment: "")
        case SettingsSection.kSettingsSectionConfiguration.rawValue:
            return NSLocalizedString("Configuration", comment: "")
        case SettingsSection.kSettingsSectionAbout.rawValue:
            return NSLocalizedString("About", comment: "")
        default:
            break
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let sections = getSettingsSections()
        let settignsSection = (sections[section] as? Int)!

        if settignsSection == SettingsSection.kSettingsSectionAbout.rawValue {
            let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)!
            let appVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)!
            return appName + appVersion + copyright
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        var cell = UITableViewCell()
        let videoConfigurationCellIdentifier = "VideoConfigurationCellIdentifier"
        let browserConfigurationCellIdentifier = "BrowserConfigurationCellIdentifier"
        let readStatusCellIdentifier = "ReadStatusCellIdentifier"
        let contactsSyncCellIdentifier = "ContactsSyncCellIdentifier"
        let privacyCellIdentifier = "PrivacyCellIdentifier"
        let sourceCodeCellIdentifier = "SourceCodeCellIdentifier"
        let userStatusCellIdentifier = "UserStatusCellIdentifier"

        let sections = getSettingsSections()
        let settingsSection = (sections[indexPath.section] as? Int)!

        switch settingsSection {
        case SettingsSection.kSettingsSectionUser.rawValue:
            let cell = (tableView.dequeueReusableCell(withIdentifier: kUserSettingsCellIdentifier, for: indexPath) as? SettingsUserTableViewCell)!
            let activeAccount = NCDatabaseManager.sharedInstance().activeAccount()
            cell.userDisplayNameLabel.text = activeAccount.userDisplayName
            let accountServer = activeAccount.server
            cell.serverAddressLabel.text = accountServer.replacingOccurrences(of: "https://", with: "")
            cell.userImageView.image = NCAPIController.sharedInstance().userProfileImage(for: activeAccount, with: CGSize(width: 160, height: 160))
            cell.accessoryType = .disclosureIndicator
            return cell
        case SettingsSection.kSettingsSectionUserStatus.rawValue:
            cell = UITableViewCell(style: .default, reuseIdentifier: userStatusCellIdentifier)
            if activeUserStatus != nil {
                cell.textLabel?.text = activeUserStatus!.readableUserStatus()
                let statusImage = activeUserStatus!.userStatusImageName(ofSize: 24)
                cell.imageView?.image = UIImage(named: statusImage)
            } else {
                cell.textLabel?.text = NSLocalizedString("Fetching status ...", comment: "")
            }
            cell.accessoryType = .disclosureIndicator
        case SettingsSection.kSettingsSectionAccounts.rawValue:
            let inactiveAccounts = NCDatabaseManager.sharedInstance().inactiveAccounts()
            let account = (inactiveAccounts[indexPath.row] as? TalkAccount)!
            let cell = UserAccountTableViewCell(style: .default, reuseIdentifier: kAccountCellIdentifier)
            cell.accountNameLabel.text = account.userDisplayName
            let accountServer = account.server.replacingOccurrences(of: "https://", with: "")
            cell.accountServerLabel.text = accountServer
            cell.accountImageView.image = NCAPIController.sharedInstance().userProfileImage(for: account, with: CGSize(width: 90, height: 90))
            cell.accessoryView = nil
            if account.unreadBadgeNumber > 0 {
                let badgeView = RoundedNumberView()
                badgeView.number = account.unreadBadgeNumber
                cell.accessoryView = badgeView
            }
            return cell
        case SettingsSection.kSettingsSectionConfiguration.rawValue:
            let options = getConfigurationSectionOptions()
            let option = options[indexPath.row]
            switch option {
            case ConfigurationSectionOption.kConfigurationSectionOptionVideo.rawValue:
                cell = UITableViewCell(style: .value1, reuseIdentifier: videoConfigurationCellIdentifier)
                cell.textLabel?.text = NSLocalizedString("Video quality", comment: "")
                cell.imageView?.image = UIImage(named: "video")?.withRenderingMode(.alwaysTemplate)
                cell.imageView?.tintColor = UIColor(red: 0.43, green: 0.43, blue: 0.45, alpha: 1)
                let resolution = NCSettingsController.sharedInstance().videoSettingsModel.currentVideoResolutionSettingFromStore()
                cell.detailTextLabel?.text = NCSettingsController.sharedInstance().videoSettingsModel.readableResolution(resolution)
            case ConfigurationSectionOption.kConfigurationSectionOptionBrowser.rawValue:
                cell = UITableViewCell(style: .value1, reuseIdentifier: browserConfigurationCellIdentifier)
                cell.textLabel?.text = NSLocalizedString("Open links in", comment: "")
                cell.imageView?.contentMode = .center
                cell.imageView?.image = UIImage(named: "browser-settings")
                cell.detailTextLabel?.text = NCUserDefaults.defaultBrowser()
            case ConfigurationSectionOption.kConfigurationSectionOptionReadStatus.rawValue:
                cell = UITableViewCell(style: .default, reuseIdentifier: readStatusCellIdentifier)
                cell.textLabel?.text = NSLocalizedString("Read status", comment: "")
                cell.selectionStyle = .none
                cell.imageView?.contentMode = .scaleAspectFit
                cell.imageView?.image = UIImage(named: "check-all")?.withRenderingMode(.alwaysTemplate)
                cell.imageView?.tintColor = UIColor(red: 0.43, green: 0.43, blue: 0.45, alpha: 1)
                cell.accessoryView = readStatusSwitch
                let activeAccount = NCDatabaseManager.sharedInstance().activeAccount()
                let serverCapabilities = NCDatabaseManager.sharedInstance().serverCapabilities(forAccountId: activeAccount.accountId)
                readStatusSwitch?.isOn = !serverCapabilities.readStatusPrivacy
            case ConfigurationSectionOption.kConfigurationSectionOptionContactsSync.rawValue:
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: contactsSyncCellIdentifier)
                cell.textLabel?.text = NSLocalizedString("Phone number", comment: "")
                cell.detailTextLabel?.text = NSLocalizedString("Match system contacts", comment: "")
                cell.selectionStyle = .none
                cell.imageView?.contentMode = .scaleAspectFit
                cell.imageView?.image = UIImage(named: "mobile-phone")?.withRenderingMode(.alwaysTemplate)
                cell.imageView?.tintColor = UIColor(red: 0.43, green: 0.43, blue: 0.45, alpha: 1)
                cell.accessoryView = contactSyncSwitch
                contactSyncSwitch?.isOn = NCSettingsController.sharedInstance().isContactSyncEnabled()
            default:
                break
            }
        case SettingsSection.kSettingsSectionAbout.rawValue:
            switch indexPath.row {
            case AboutSection.kAboutSectionPrivacy.rawValue:
                cell =
                UITableViewCell(style: .default, reuseIdentifier: privacyCellIdentifier)
                cell.textLabel?.text = NSLocalizedString("Privacy", comment: "")
                cell.imageView?.image = UIImage(named: "privacy")
            case AboutSection.kAboutSectionSourceCode.rawValue:
                cell =
                UITableViewCell(style: .default, reuseIdentifier: sourceCodeCellIdentifier)
                cell.textLabel?.text = NSLocalizedString("Get source code", comment: "")
                cell.imageView?.image = UIImage(named: "github")
            default:
                break
            }
        default:
            break
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sections = getSettingsSections()
        let settingsSection = (sections[indexPath.section] as? Int)!
        switch settingsSection {
        case SettingsSection.kSettingsSectionUser.rawValue:
            self.userProfilePressed()
        case SettingsSection.kSettingsSectionUserStatus.rawValue:
            self.presetnUserStatusOptions()
        case SettingsSection.kSettingsSectionAccounts.rawValue:
            let inactiveAccounts = NCDatabaseManager.sharedInstance().inactiveAccounts()
            let account = (inactiveAccounts[indexPath.row] as? TalkAccount)!
            NCSettingsController.sharedInstance().setActiveAccountWithAccountId(account.accountId)
        case SettingsSection.kSettingsSectionConfiguration.rawValue:
            let options = getConfigurationSectionOptions()
            let option = options[indexPath.row]
            switch option {
            case ConfigurationSectionOption.kConfigurationSectionOptionVideo.rawValue:
                self.presentVideoResoultionsSelector()
            case ConfigurationSectionOption.kConfigurationSectionOptionBrowser.rawValue:
                self.presentBrowserSelector()
            case ConfigurationSectionOption.kConfigurationSectionOptionReadStatus.rawValue:
                break
            case ConfigurationSectionOption.kConfigurationSectionOptionContactsSync.rawValue:
                break
            default:
                break
            }
        case SettingsSection.kSettingsSectionAbout.rawValue:
            switch indexPath.row {
            case AboutSection.kAboutSectionPrivacy.rawValue:
                let safariVC = SFSafariViewController(url: URL(string: "https://nextcloud.com/privacy")!)
                self.present(safariVC, animated: true, completion: nil)
            case AboutSection.kAboutSectionSourceCode.rawValue:
                let safariVC = SFSafariViewController(url: URL(string: "https://github.com/nextcloud/talk-ios")!)
                self.present(safariVC, animated: true, completion: nil)
            default:
                break
            }
        default:
            break
        }
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
}