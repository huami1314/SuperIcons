//
//  MyAction.swift
//  SuperIcons
//
//  Created by huami on 2024/7/31.
//

import Foundation
import UIKit

class MyAction {
    
    private static var cpBinaryURL: URL = {
        if #available(iOS 16.0, *) {
            return Bundle.main.url(forResource: "cp", withExtension: nil)!
        } else {
            return Bundle.main.url(forResource: "cp-15", withExtension: nil)!
        }
    }()
    
    private static var mvBinaryURL: URL = {
        if #available(iOS 16.0, *) {
            return Bundle.main.url(forResource: "mv", withExtension: nil)!
        } else {
            return Bundle.main.url(forResource: "mv-15", withExtension: nil)!
        }
    }()
    
    private static var rmBinaryURL: URL = {
        if #available(iOS 16.0, *) {
            return Bundle.main.url(forResource: "rm", withExtension: nil)!
        } else {
            return Bundle.main.url(forResource: "rm", withExtension: nil)!
        }
    }()
    
    static func changeIcons(mainpath: String, iconPath: String, iconName: String) {
        let fileManager = FileManager.default
        let tempDirectoryURL = URL(fileURLWithPath: "/tmp").appendingPathComponent(UUID().uuidString)
        
        do {
            try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            showErrorAlert(error: error)
            return
        }
        
        let infoPlistURL = URL(fileURLWithPath: mainpath)
        let backupPlistURL = infoPlistURL.deletingLastPathComponent().appendingPathComponent("Info.plist.bak")
        let tempInfoPlistURL = tempDirectoryURL.appendingPathComponent("Info.plist")
        let iconDestinationURL = infoPlistURL.deletingLastPathComponent().appendingPathComponent(iconName)
        
        var convertIconURL = URL(fileURLWithPath: iconPath)
        
        if iconPath.lowercased().hasSuffix(".jpeg") || iconPath.lowercased().hasSuffix(".jpg") {
            let pngIconPath = tempDirectoryURL.appendingPathComponent("\(UUID().uuidString).png").path
            guard let jpegData = FileManager.default.contents(atPath: iconPath),
                  let image = UIImage(data: jpegData),
                  let pngData = image.pngData() else {
                showErrorAlert(error: NSError(domain: "ConvertJPEGToPNGError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JPEG to PNG"]))
                return
            }
            do {
                try pngData.write(to: URL(fileURLWithPath: pngIconPath))
                convertIconURL = URL(fileURLWithPath: pngIconPath)
            } catch {
                showErrorAlert(error: error)
                return
            }
        }
        
        var success = false
        
        do {
            try copyURL(infoPlistURL, to: backupPlistURL)
            try copyURL(infoPlistURL, to: tempInfoPlistURL)
            try copyURL(convertIconURL, to: iconDestinationURL)
            try updateInfoPlist(at: tempInfoPlistURL, withIconName: iconName)
            try copyURL(tempInfoPlistURL, to: infoPlistURL)
            success = true
        } catch {
            showErrorAlert(error: error)
        }
        
        showResultAlert(success: success)
    }
    
    static func restoreIcons(mainpath: String) {
        let fileManager = FileManager.default
        let infoPlistURL = URL(fileURLWithPath: mainpath)
        let backupURL = infoPlistURL.deletingLastPathComponent().appendingPathComponent("Info.plist.bak")
        
        var success = false
        
        if !fileManager.fileExists(atPath: backupURL.path) {
            showErrorAlert(error: NSError(domain: "MyActionErrorDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("No backup found. Please change the icon before attempting to restore.", comment: "")]))
            return
        }
        
        do {
            try removeURL(infoPlistURL)
            try removeURL(infoPlistURL.deletingLastPathComponent().appendingPathComponent("AppIcon_AA.png"))
            try moveURL(backupURL, to: infoPlistURL)
            success = true
        } catch {
            showErrorAlert(error: error)
        }
        
        showResultAlert(success: success)
    }
    
    private static func copyURL(_ src: URL, to dst: URL) throws {
        let retCode = try Execute.rootSpawnWithOutputs(binary: cpBinaryURL.path, arguments: ["-rfp", src.path, dst.path])
        guard case .exit(let code) = retCode.terminationReason, code == 0 else {
            throw CommandFailureError(command: "cp", reason: retCode.terminationReason)
        }
    }
    
    private static func removeURL(_ url: URL) throws {
        let retCode = try Execute.rootSpawnWithOutputs(binary: rmBinaryURL.path, arguments: ["-rf", url.path])
        guard case .exit(let code) = retCode.terminationReason, code == 0 else {
            throw CommandFailureError(command: "rm", reason: retCode.terminationReason)
        }
    }
    
    private static func moveURL(_ src: URL, to dst: URL) throws {
        let retCode = try Execute.rootSpawnWithOutputs(binary: mvBinaryURL.path, arguments: ["-f", src.path, dst.path])
        guard case .exit(let code) = retCode.terminationReason, code == 0 else {
            throw CommandFailureError(command: "mv", reason: retCode.terminationReason)
        }
    }
    
    private static func updateInfoPlist(at url: URL, withIconName iconName: String) throws {
        guard let plist = NSMutableDictionary(contentsOf: url) else {
            throw NSError(domain: "MyActionErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Unable to read Info.plist", comment: "")])
        }
        
        replaceAppIconNames(in: plist, with: iconName)
        
        if !plist.write(to: url, atomically: true) {
            throw NSError(domain: "MyActionErrorDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Unable to write Info.plist", comment: "")])
        }
    }
    
    private static func replaceAppIconNames(in dict: NSMutableDictionary, with iconName: String) {
        for (key, value) in dict {
            if let keyString = key as? String, keyString.hasPrefix("CFBundleIcon") || keyString.hasPrefix("AppIcon") {
                dict[key] = iconName
            } else if let subDict = value as? NSMutableDictionary {
                replaceAppIconNames(in: subDict, with: iconName)
            } else if let array = value as? [Any] {
                let newArray = array.map { item -> Any in
                    if let subDict = item as? NSMutableDictionary {
                        replaceAppIconNames(in: subDict, with: iconName)
                        return subDict
                    }
                    return item
                }
                dict[key] = newArray
            }
        }
    }
    
    private static func showErrorAlert(error: Error) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
        }
    }
    
    private static func showResultAlert(success: Bool) {
        DispatchQueue.main.async {
            let title = success ? NSLocalizedString("Success", comment: "") : NSLocalizedString("Failure", comment: "")
            let message = success ? NSLocalizedString("Operation successful. Please rebuild the icon cache.", comment: "") : NSLocalizedString("Operation failed", comment: "")
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
                if success {
                    openTrollStore()
                }
            })
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
        }
    }
    
    private static func openTrollStore() {
        if let url = URL(string: "apple-magnifier://") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

struct CommandFailureError: Error {
    let command: String
    let reason: AuxiliaryExecute.TerminationReason
    
    var localizedDescription: String {
        return "\(command) command failed with reason: \(reason)"
    }
}
