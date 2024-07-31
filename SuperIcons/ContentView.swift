import SwiftUI

struct ContentView: View {
    @State private var searchText = ""
    @State private var appDetails: [(name: String, bundleID: String, version: String, icon: UIImage?, infoPlistPath: String)] = []
    @State private var selectedIconPath: String?
    @State private var showActionSheet = false
    @State private var showFilePicker = false
    @State private var selectedAppDetail: (name: String, bundleID: String, version: String, icon: UIImage?, infoPlistPath: String)? = nil

    var filteredAppDetails: [(name: String, bundleID: String, version: String, icon: UIImage?, infoPlistPath: String)] {
        let isValidApp = { (bundleID: String, appType: String) -> Bool in
            return appType != "User" && !bundleID.starts(with: "com.apple")
        }
        
        let filtered = searchText.isEmpty
            ? appDetails.filter { isValidApp($0.bundleID, $0.infoPlistPath) }
            : appDetails.filter {
                isValidApp($0.bundleID, $0.infoPlistPath) && $0.name.localizedCaseInsensitiveContains(searchText)
            }
            
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationView {
            VStack {
                if #available(iOS 15.0, *) {
                    List {
                        ForEach(filteredAppDetails, id: \.bundleID) { appDetail in
                            Button(action: {
                                selectedAppDetail = appDetail
                                showActionSheet = true
                            }) {
                                HStack {
                                    if let icon = appDetail.icon {
                                        Image(uiImage: icon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                            .padding(.leading)
                                    } else {
                                        Image(systemName: "app")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                            .padding(.leading)
                                    }

                                    VStack(alignment: .leading) {
                                        Text(appDetail.name)
                                            .font(.headline)
                                        Text("Bundle ID: \(appDetail.bundleID)")
                                            .font(.subheadline)
                                        Text("Version: \(appDetail.version)")
                                            .font(.subheadline)
                                    }
                                    .padding(.leading)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .background(Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowInsets(EdgeInsets())
                        }
                        FooterView()
                    }
                    .searchable(text: $searchText, prompt: NSLocalizedString("Search...", comment: "Search prompt"))
                    .listStyle(PlainListStyle())
                } else {
                    VStack {
                        TextField(NSLocalizedString("Search...", comment: "Search placeholder"), text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding()
                        
                        List {
                            ForEach(filteredAppDetails, id: \.bundleID) { appDetail in
                                Button(action: {
                                    selectedAppDetail = appDetail
                                    showActionSheet = true
                                }) {
                                    HStack {
                                        if let icon = appDetail.icon {
                                            Image(uiImage: icon)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                                .padding(.leading)
                                        } else {
                                            Image(systemName: "app")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                                .padding(.leading)
                                        }

                                        VStack(alignment: .leading) {
                                            Text(appDetail.name)
                                                .font(.headline)
                                            Text("Bundle ID: \(appDetail.bundleID)")
                                                .font(.subheadline)
                                            Text("Version: \(appDetail.version)")
                                                .font(.subheadline)
                                        }
                                        .padding(.leading)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .background(Color.clear)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .listRowInsets(EdgeInsets())
                            }
                            FooterView()
                        }
                    }
                }
            }
            .onAppear {
                fetchAppDetails()
            }
            .navigationTitle(NSLocalizedString("SuperIcons", comment: "Navigation title"))
            .actionSheet(isPresented: $showActionSheet) {
                ActionSheet(
                    title: Text(NSLocalizedString("Select Action", comment: "Action sheet title")),
                    buttons: [
                        .default(Text(NSLocalizedString("Change Icon", comment: "Change icon action"))) {
                            showFilePicker = true
                        },
                        .default(Text(NSLocalizedString("Restore Icon", comment: "Restore icon action"))) {
                            if let appDetail = selectedAppDetail {
                                MyAction.restoreIcons(mainpath: appDetail.infoPlistPath)
                            }
                        },
                        .cancel()
                    ]
                )
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.png, .jpeg]) { result in
                switch result {
                case .success(let url):
                    selectedIconPath = url.path
                    if let appDetail = selectedAppDetail {
                        MyAction.changeIcons(mainpath: appDetail.infoPlistPath, iconPath: selectedIconPath!, iconName: "AppIcon_AA.png")
                    }
                case .failure(let error):
                    print(NSLocalizedString("Error selecting file: \(error.localizedDescription)", comment: "File selection error"))
                }
            }
        }
    }

    func fetchAppDetails() {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace")).takeUnretainedValue() as? NSObject,
              let applications = workspace.perform(NSSelectorFromString("allApplications")).takeUnretainedValue() as? [NSObject] else {
            return
        }

        appDetails = applications.compactMap { app in
            if let bundleID = app.perform(NSSelectorFromString("applicationIdentifier")).takeUnretainedValue() as? String,
               let bundlePath = app.perform(NSSelectorFromString("bundleURL")).takeUnretainedValue() as? URL,
               let appType = app.perform(NSSelectorFromString("applicationType")).takeUnretainedValue() as? String {

                if appType != "User" && !bundleID.starts(with: "com.apple") {
                    let infoPlistPath = bundlePath.appendingPathComponent("Info.plist").path
                    if FileManager.default.fileExists(atPath: infoPlistPath),
                       let infoDict = NSDictionary(contentsOfFile: infoPlistPath),
                       let displayName = infoDict["CFBundleDisplayName"] as? String,
                       let version = infoDict["CFBundleShortVersionString"] as? String {
                        let icon = getAppIcon(from: bundlePath)
                        return (name: displayName, bundleID: bundleID, version: version, icon: icon, infoPlistPath: infoPlistPath)
                    }
                }
            }
            return nil
        }
    }

    func getAppIcon(from bundleURL: URL) -> UIImage? {
        let possibleIconPaths = [
            "AppIcon_AA.png",
            "AppIcon60x60@2x.png",
            "AppIcon76x76@2x.png",
            "AppIcon83.5x83.5@2x.png",
            "AppIcon40x40@2x.png",
            "AppIcon29x29@2x.png",
            "AppIcon.png",
            "Icon.png",
            "icon.png",
            "Icon-60.png",
            "icon-60.png"
        ]

        for iconName in possibleIconPaths {
            let iconPath = bundleURL.appendingPathComponent(iconName)
            if let image = UIImage(contentsOfFile: iconPath.path) {
                return image
            }
        }

        return nil
    }
}

struct FooterView: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("SuperIcons v1.0 (1) ©️ 2024", comment: "Footer text"))
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Text(NSLocalizedString("Developed by huami.", comment: "Developer text"))
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                Spacer()
                Link(NSLocalizedString("Get Repository", comment: "Repository link text"), destination: URL(string: "https://github.com/huami1314/SuperIcons")!)
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .padding(.horizontal)
            }
            .padding()
            .background(Color(.systemGray6))
        }
    }
}

struct FooterView_Previews: PreviewProvider {
    static var previews: some View {
        FooterView()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
