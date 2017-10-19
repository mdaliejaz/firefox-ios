/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import XCTest

let FirstRun = "OptionalFirstRun"
let TabTray = "TabTray"
let PrivateTabTray = "PrivateTabTray"
let NewTabScreen = "NewTabScreen"
let URLBarOpen = "URLBarOpen"
let URLBarLongPressMenu = "URLBarLongPressMenu"
let ReloadLongPressMenu = "ReloadLongPressMenu"
let PrivateURLBarOpen = "PrivateURLBarOpen"
let BrowserTab = "BrowserTab"
let PrivateBrowserTab = "PrivateBrowserTab"
let BrowserTabMenu = "BrowserTabMenu"
let PageOptionsMenu = "PageOptionsMenu"
let FindInPage = "FindInPage"
let SettingsScreen = "SettingsScreen"
let HomePageSettings = "HomePageSettings"
let PasscodeSettings = "PasscodeSettings"
let PasscodeIntervalSettings = "PasscodeIntervalSettings"
let SearchSettings = "SearchSettings"
let NewTabSettings = "NewTabSettings"
let ClearPrivateDataSettings = "ClearPrivateDataSettings"
let LoginsSettings = "LoginsSettings"
let OpenWithSettings = "OpenWithSettings"
let ShowTourInSettings = "ShowTourInSettings"
let Intro_FxASignin = "Intro_FxASignin"
let WebImageContextMenu = "WebImageContextMenu"
let WebLinkContextMenu = "WebLinkContextMenu"
let CloseTabMenu = "CloseTabMenu"

let allSettingsScreens = [
    SettingsScreen,
    HomePageSettings,
    PasscodeSettings,
    SearchSettings,
    NewTabSettings,
    ClearPrivateDataSettings,
    LoginsSettings,
    OpenWithSettings
]

let Intro_Welcome = "Intro.Welcome"
let Intro_Search = "Intro.Search"
let Intro_Private = "Intro.Private"
let Intro_Mail = "Intro.Mail"
let Intro_Sync = "Intro.Sync"

let allIntroPages = [
    Intro_Welcome,
    Intro_Search,
    Intro_Private,
    Intro_Mail,
    Intro_Sync
]

let HomePanelsScreen = "HomePanels"
let PrivateHomePanelsScreen = "PrivateHomePanels"
let HomePanel_TopSites = "HomePanel.TopSites.0"
let HomePanel_Bookmarks = "HomePanel.Bookmarks.1"
let HomePanel_History = "HomePanel.History.2"
let HomePanel_ReadingList = "HomePanel.ReadingList.3"
let P_HomePanel_TopSites = "P_HomePanel.TopSites.0"
let P_HomePanel_Bookmarks = "P_HomePanel.Bookmarks.1"
let P_HomePanel_History = "P_HomePanel.History.2"
let P_HomePanel_ReadingList = "P_HomePanel.ReadingList.3"

let allHomePanels = [
    HomePanel_Bookmarks,
    HomePanel_TopSites,
    HomePanel_History,
    HomePanel_ReadingList
]
let allPrivateHomePanels = [
    P_HomePanel_Bookmarks,
    P_HomePanel_TopSites,
    P_HomePanel_History,
    P_HomePanel_ReadingList
]

class Action {
    static let LoadURL = "LoadURL"
    static let LoadURLByTyping = "LoadURLByTyping"
    static let LoadURLByPasting = "LoadURLByPasting"

    static let SetURL = "SetURL"
    static let SetURLByTyping = "SetURLByTyping"
    static let SetURLByPasting = "SetURLByPasting"

    static let ReloadURL = "ReloadURL"

    static let TogglePrivateMode = "TogglePrivateBrowing"
    static let ToggleRequestDesktopSite = "ToggleRequestDesktopSite"
}

class FxUserState: UserState {
    required init() {
        super.init()
        initialScreenState = FirstRun
    }

    var isPrivate = false
    var showIntro = false
    var showWhatsNew = false
    var url: String? = nil
    var requestDesktopSite = false
}

fileprivate let defaultURL = "https://www.mozilla.org/en-US/book/"

func createScreenGraph(for test: XCTestCase, with app: XCUIApplication) -> ScreenGraph<FxUserState> {
    let map = ScreenGraph(for: test, with: FxUserState.self)

    let introScrollView = app.scrollViews["IntroViewController.scrollView"]
    map.addScreenState(FirstRun) { scene in
        scene.noop(to: BrowserTab, if: "showIntro == false && showWhatsNew == true")
        scene.noop(to: NewTabScreen, if: "showIntro == false && showWhatsNew == false")
        scene.noop(to: allIntroPages[0], if: "showIntro == true")
    }

    // Add the intro screens.
    var i = 0
    let introLast = allIntroPages.count - 1
    let introPager = app.scrollViews["IntroViewController.scrollView"]
    for intro in allIntroPages {
        let prev = i == 0 ? nil : allIntroPages[i - 1]
        let next = i == introLast ? nil : allIntroPages[i + 1]

        map.addScreenState(intro) { scene in
            if let prev = prev {
                scene.swipeRight(introPager, to: prev)
            }

            if let next = next {
                scene.swipeLeft(introPager, to: next)
            }

            if i > 0 {
                let startBrowsingButton = app.buttons["IntroViewController.startBrowsingButton"]
                scene.tap(startBrowsingButton, to: BrowserTab)
            }
        }

        i += 1
    }

    let noopAction = {}

    // Some internally useful screen states.
    let URLBarAvailable = "URLBarAvailable"
    let Loading = "Loading"
    let ToolBarAvailable = "ToolBarAvailable"


    map.addScreenState(NewTabScreen) { screenState in
        screenState.noop(to: HomePanelsScreen)
        screenState.noop(to: URLBarAvailable)
        screenState.tap(app.buttons["TabToolbar.menuButton"], to: BrowserTabMenu)
    }

    map.addScreenState(URLBarAvailable) { screenState in
        screenState.backAction = noopAction
        screenState.tap(app.textFields["url"], to: URLBarOpen)
        screenState.gesture(to: URLBarLongPressMenu) {
            app.textFields["url"].press(forDuration: 1.0)
        }
    }

    map.addScreenState(URLBarLongPressMenu) { screenState in
        let menu = app.sheets.element(boundBy: 0)
        screenState.onEnter(element: menu)

        screenState.gesture(forAction: Action.LoadURLByPasting, Action.LoadURL) { userState in
            UIPasteboard.general.string = userState.url ?? defaultURL
            menu.buttons.element(boundBy: 0).tap()
        }

        screenState.gesture(forAction: Action.SetURLByPasting) { userState in
            UIPasteboard.general.string = userState.url ?? defaultURL
            menu.buttons.element(boundBy: 1).tap()
        }

        screenState.backAction = {
            menu.buttons.element(boundBy: 3).tap()
        }

        screenState.dismissOnUse = true
    }

    map.addScreenState(URLBarOpen) { scene in
        // This is used for opening BrowserTab with default mozilla URL
        // For custom URL, should use Navigator.openNewURL or Navigator.openURL.
        scene.gesture(forAction: Action.LoadURLByTyping, Action.LoadURL) { userState in
            let url = userState.url ?? defaultURL
            app.textFields["address"].typeText("\(url)\r")
        }

        scene.gesture(forAction: Action.SetURLByTyping, Action.SetURL) { userState in
            let url = userState.url ?? defaultURL
            app.textFields["address"].typeText("\(url)")
        }

        scene.noop(to: HomePanelsScreen)

        scene.backAction = {
            app.buttons["urlBar-cancel"].tap()
        }
    }

    map.addScreenAction(Action.LoadURL, transitionTo: Loading) { _ in }
    map.addScreenState(Loading) { screenState in
        screenState.onEnter("exists != true", element: app.progressIndicators.element(boundBy: 0))
        screenState.noop(to: BrowserTab)
    }

    map.createScene(HomePanelsScreen) { scene in
        scene.tap(app.buttons["HomePanels.TopSites"], to: HomePanel_TopSites)
        scene.tap(app.buttons["HomePanels.Bookmarks"], to: HomePanel_Bookmarks)
        scene.tap(app.buttons["HomePanels.History"], to: HomePanel_History)
        scene.tap(app.buttons["HomePanels.ReadingList"], to: HomePanel_ReadingList)

        if map.isiPad() {
            scene.tap(app.buttons["TopTabsViewController.tabsButton"], to: TabTray)
        } else {
            scene.gesture(to: TabTray) {
                if (app.buttons["TabToolbar.tabsButton"].exists) {
                    app.buttons["TabToolbar.tabsButton"].tap()
                } else {
                    app.buttons["URLBarView.tabsButton"].tap()
                }
            }
        }
    }

    allHomePanels.forEach { name in
        // Tab panel means that all the home panels are available all the time, so we can 
        // fake this out by a noop back to the HomePanelsScreen which can get to every other panel.
        map.createScene(name) { scene in
            scene.backAction = noopAction
        }
    }

    let navigationControllerBackAction = {
        app.navigationBars.element(boundBy: 0).buttons.element(boundBy: 0).tap()
    }

    let cancelBackAction = {
        app.buttons["PhotonMenu.cancel"].tap()
    }

    let backBtnBackAction = {
        if map.isiPad() {
            app.buttons["URLBarView.backButton"].tap()
        }
        else {
            app.buttons["TabToolbar.backButton"].tap()
        }
    }

    map.createScene(SettingsScreen) { scene in
        let table = app.tables["AppSettingsTableViewController.tableView"]

        scene.tap(table.cells["Search"], to: SearchSettings)
        scene.tap(table.cells["NewTab"], to: NewTabSettings)
        scene.tap(table.cells["Homepage"], to: HomePageSettings)
        scene.tap(table.cells["TouchIDPasscode"], to: PasscodeSettings)
        scene.tap(table.cells["Logins"], to: LoginsSettings)
        scene.tap(table.cells["ClearPrivateData"], to: ClearPrivateDataSettings)
        scene.tap(table.cells["OpenWith.Setting"], to: OpenWithSettings)
        scene.tap(table.cells["ShowTour"], to: ShowTourInSettings)

        scene.backAction = navigationControllerBackAction
    }

    map.createScene(SearchSettings) { scene in
        scene.backAction = navigationControllerBackAction
    }

    map.createScene(NewTabSettings) { scene in
        scene.backAction = navigationControllerBackAction
    }

    map.createScene(HomePageSettings) { scene in
        scene.backAction = navigationControllerBackAction
    }

    map.createScene(PasscodeSettings) { scene in
        scene.backAction = navigationControllerBackAction

        scene.tap(app.tables["AuthenticationManager.settingsTableView"].staticTexts["Require Passcode"], to: PasscodeIntervalSettings)
    }

    map.createScene(PasscodeIntervalSettings) { scene in
        // The test is likely to know what it needs to do here.
        // This screen is protected by a passcode and is essentially modal.
        scene.gesture(to: PasscodeSettings) {
            if app.navigationBars["Require Passcode"].exists {
                // Go back, accepting modifications
                app.navigationBars["Require Passcode"].buttons["Passcode For Logins"].tap()
            } else {
                // Cancel
                app.navigationBars["Enter Passcode"].buttons["Cancel"].tap()
            }
        }
    }

    map.createScene(LoginsSettings) { scene in
        scene.gesture(to: SettingsScreen) {
            let loginList = app.tables["Login List"]
            if loginList.exists {
                app.navigationBars["Logins"].buttons["Settings"].tap()
            } else {
                app.navigationBars["Enter Passcode"].buttons["Cancel"].tap()
            }
        }
    }

    map.createScene(ClearPrivateDataSettings) { scene in
        scene.backAction = navigationControllerBackAction
    }

    map.createScene(OpenWithSettings) { scene in
        scene.backAction = navigationControllerBackAction
    }

    map.createScene(ShowTourInSettings) { scene in
        scene.gesture(to: Intro_FxASignin) {
            let introScrollView = app.scrollViews["IntroViewController.scrollView"]
            for _ in 1...4 {
                introScrollView.swipeLeft()
            }
            app.buttons["Sign in to Firefox"].tap()
        }
        scene.backAction = {
            introScrollView.swipeLeft()
            let startBrowsingButton = app.buttons["IntroViewController.startBrowsingButton"]
            startBrowsingButton.tap()
        }
    }

    map.createScene(Intro_FxASignin) { scene in
       scene.tap(app.navigationBars["Client.FxAContentView"].buttons.element(boundBy: 0), to: HomePanelsScreen)
    }

    map.createScene(TabTray) { scene in
        scene.tap(app.buttons["TabTrayController.addTabButton"], to: NewTabScreen)
        scene.tap(app.buttons["TabTrayController.maskButton"], forAction: Action.TogglePrivateMode) { userState in
            userState.isPrivate = !userState.isPrivate
        }
        scene.tap(app.buttons["TabTrayController.removeTabsButton"], to: CloseTabMenu)
    }

    map.addScreenState(CloseTabMenu) { screenState in
        screenState.backAction = cancelBackAction
    }

    let lastButtonIsCancel = {
        let lastIndex = app.sheets.element(boundBy: 0).buttons.count - 1
        app.sheets.element(boundBy: 0).buttons.element(boundBy: lastIndex).tap()
    }

    map.addScreenState(ToolBarAvailable) { screenState in
        screenState.backAction = noopAction

        screenState.tap(app.buttons["TabLocationView.pageOptionsButton"], to: PageOptionsMenu)
        screenState.tap(app.buttons["TabToolbar.menuButton"], to: BrowserTabMenu)
        if map.isiPad() {
            screenState.tap(app.buttons["TopTabsViewController.tabsButton"], to: TabTray)
        } else {
            screenState.gesture(to: TabTray) {
                if (app.buttons["TabToolbar.tabsButton"].exists) {
                    app.buttons["TabToolbar.tabsButton"].tap()
                } else {
                    app.buttons["URLBarView.tabsButton"].tap()
                }
            }
        }
    }

    map.createScene(BrowserTab) { scene in
        scene.noop(to: URLBarAvailable)
        scene.noop(to: ToolBarAvailable)

        let link = app.webViews.element(boundBy: 0).links.element(boundBy: 0)
        let image = app.webViews.element(boundBy: 0).images.element(boundBy: 0)

        scene.press(link, to: WebLinkContextMenu)
        scene.press(image, to: WebImageContextMenu)

        let reloadButton = app.buttons["TabToolbar.stopReloadButton"]
        scene.press(reloadButton, to: ReloadLongPressMenu)
        scene.tap(reloadButton, forAction: Action.ReloadURL, transitionTo: Loading) { _ in }

        scene.backAction = backBtnBackAction
    }

    map.addScreenState(ReloadLongPressMenu) { screenState in
        screenState.backAction = lastButtonIsCancel
        screenState.dismissOnUse = true

        let rdsButton = app.cells["menu-RequestDesktopSite"]
        screenState.tap(rdsButton, forAction: Action.ToggleRequestDesktopSite) { userState in
            userState.requestDesktopSite = !userState.requestDesktopSite
        }
    }

    map.addScreenState(WebImageContextMenu) { screenState in
        screenState.dismissOnUse = true
        screenState.backAction = lastButtonIsCancel
    }

    map.addScreenState(WebLinkContextMenu) { screenState in
        screenState.dismissOnUse = true
        screenState.backAction = lastButtonIsCancel
    }

    // make sure after the menu action, navigator.nowAt() is used to set the current state
    map.createScene(PageOptionsMenu) {scene in
        scene.tap(app.tables["Context Menu"].cells["Find in Page"], to: FindInPage)
        scene.backAction = cancelBackAction
        scene.dismissOnUse = true
    }

    map.createScene(FindInPage) {scene in
        scene.tap(app.buttons["FindInPage.close"], to: BrowserTab)
    }

    map.createScene(BrowserTabMenu) { scene in
        scene.tap(app.tables.cells["Settings"], to: SettingsScreen)

        scene.dismissOnUse = true
        scene.backAction = cancelBackAction
    }

    return map
}
extension ScreenGraph {

    // Checks whether the current device is iPad or non-iPad
    func isiPad() -> Bool {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        }
        return false
    }
}

extension Navigator {

    // Open a URL. Will use/re-use the first BrowserTab or NewTabScreen it comes to.
    func openURL(urlString: String) {
        self.goto(URLBarOpen)
        let app = XCUIApplication()
        app.textFields["address"].typeText(urlString + "\r")

        self.nowAt(BrowserTab)
    }

    // Opens a URL in a new tab.
    func openNewURL(urlString: String) {
        self.goto(TabTray)
        createNewTab()
        self.openURL(urlString: urlString)
    }

    // Closes all Tabs from the option in TabTrayMenu
    func closeAllTabs() {
        let app = XCUIApplication()
        app.buttons["TabTrayController.removeTabsButton"].tap()
        app.sheets.buttons["Close All Tabs"].tap()
        self.nowAt(HomePanelsScreen)
    }

    // Add a new Tab from the New Tab option in Browser Tab Menu
    func createNewTab() {
        let app = XCUIApplication()
        self.goto(TabTray)
        app.buttons["TabTrayController.addTabButton"].tap()
        self.nowAt(HomePanelsScreen)
    }

    // Add Tab(s) from the Tab Tray
    func createSeveralTabsFromTabTray(numberTabs: Int) {
        for _ in 1...numberTabs {
            self.goto(TabTray)
            self.goto(HomePanelsScreen)

        }
    }

    func browserPerformAction(_ view: BrowserPerformAction) {
        let PageMenuOptions = [.toggleBookmarkOption, .addReadingListOption, .copyURLOption, .findInPageOption, .toggleDesktopOption, .requestSetHomePageOption, BrowserPerformAction.shareOption]
        let BrowserMenuOptions = [.openTopSitesOption, .openBookMarksOption, .openHistoryOption, .openReadingListOption, .toggleHideImages, .toggleNightMode, BrowserPerformAction.openSettingsOption]

        let app = XCUIApplication()

        if PageMenuOptions.contains(view) {
            self.goto(PageOptionsMenu)
            app.tables["Context Menu"].cells[view.rawValue].tap()
        } else if BrowserMenuOptions.contains(view) {
            self.goto(BrowserTabMenu)
            app.tables["Context Menu"].cells[view.rawValue].tap()
        }
    }
}
enum BrowserPerformAction: String {
    // Page Menu
    case toggleBookmarkOption  = "menu-Bookmark"
    case addReadingListOption = "addToReadingList"
    case copyURLOption = "menu-Copy-Link"
    case findInPageOption = "menu-FindInPage"
    case toggleDesktopOption = "menu-RequestDesktopSite"
    case requestSetHomePageOption = "menu-Home"
    case shareOption = "action_share"

    // Tab Menu
    case openTopSitesOption = "menu-panel-TopSites"
    case openBookMarksOption = "menu-panel-Bookmarks"
    case openHistoryOption = "menu-panel-History"
    case openReadingListOption = "menu-panel-ReadingList"
    case toggleHideImages = "menu-NoImageMode"
    case toggleNightMode = "menu-NightMode"
    case openSettingsOption = "menu-Settings"
}
