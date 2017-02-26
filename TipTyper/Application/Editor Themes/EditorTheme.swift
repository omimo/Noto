//
//  EditorTheme.swift
//  TipTyper
//
//  Created by Bruno Philipe on 23/02/2017.
//  Copyright © 2017 Bruno Philipe. All rights reserved.
//

import Cocoa

protocol EditorTheme: class
{
	var name: String { get }
	
	var windowBackground: NSColor { get }
	
	var editorForeground: NSColor { get }
	var editorBackground: NSColor { get }
	
	var lineCounterForeground: NSColor { get }
	var lineCounterBackground: NSColor { get }

	var preferenceName: String? { get }
}

private let kThemeNameKey					= "name"
private let kThemeWindowBackgroundKey		= "window_background"
private let kThemeEditorBackgroundKey		= "editor_background"
private let kThemeLineCounterBackgroundKey	= "lines_background"
private let kThemeEditorForegroundKey		= "editor_foreground"
private let kThemeLineCounterForegroundKey	= "lines_foreground"

private let kThemeNativeNamePrefix = "native:"
private let kThemeUserNamePrefix = "user:"

extension EditorTheme
{
	fileprivate static var userThemeKeys: [String]
	{
		return [
			kThemeWindowBackgroundKey,
			kThemeEditorBackgroundKey,
			kThemeLineCounterBackgroundKey,
			kThemeEditorForegroundKey,
			kThemeLineCounterForegroundKey]
	}

	fileprivate var serialized: [String: AnyObject]
	{
		return [
			kThemeNameKey:					name as NSString,
			kThemeWindowBackgroundKey:		windowBackground,
			kThemeEditorBackgroundKey:		editorBackground,
			kThemeLineCounterBackgroundKey:	lineCounterBackground,
			kThemeEditorForegroundKey:		editorForeground,
			kThemeLineCounterForegroundKey:	lineCounterForeground
		]
	}
	
	func make(fromSerialized dict: [String: AnyObject]) -> EditorTheme
	{
		return ConcreteEditorTheme(fromSerialized: dict)
	}

	static func installedThemes() -> (native: [EditorTheme], user: [EditorTheme])
	{
		let nativeThemes: [EditorTheme] = [
			LightEditorTheme()
		]

		var userThemes: [EditorTheme] = []

		if let themesDirectoryURL = URLForUserThemesDirectory()
		{
			if let fileURLs = try? FileManager.default.contentsOfDirectory(at: themesDirectoryURL,
			                                                               includingPropertiesForKeys: nil,
			                                                               options: [.skipsHiddenFiles])
			{
				for fileURL in fileURLs
				{
					if fileURL.pathExtension == "plist", let theme = UserEditorTheme(fromFile: fileURL)
					{
						userThemes.append(theme)
					}
				}
			}
		}

		return (nativeThemes, userThemes)
	}

	static func URLForUserThemesDirectory() -> URL?
	{
		if let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last
		{
			let themeDirectory = appSupportDirectory.appendingPathComponent("TipTyper/Themes/")

			do
			{
				try FileManager.default.createDirectory(at: themeDirectory, withIntermediateDirectories: true, attributes: nil)
			}
			catch let error
			{
				NSLog("Could not create Themes directory: \(themeDirectory). Please check permissions. Error: \(error)")
			}

			return themeDirectory
		}

		return nil
	}

	public static func getWithPreferenceName(_ name: String) -> EditorTheme?
	{
		if name.hasPrefix(kThemeNativeNamePrefix)
		{
			let themeName = name.substring(from: name.index(name.startIndex, offsetBy: kThemeNativeNamePrefix.characters.count))

			switch themeName
			{
			case "Light":
				return LightEditorTheme()

			default:
				return nil
			}
		}
		else if name.hasPrefix(kThemeUserNamePrefix)
		{
			let themeFilePath = name.substring(from: name.index(name.startIndex, offsetBy: kThemeUserNamePrefix.characters.count))

			if FileManager.default.fileExists(atPath: themeFilePath)
			{
				return UserEditorTheme(fromFile: URL(fileURLWithPath: themeFilePath))
			}
			else
			{
				return nil
			}
		}
		else
		{
			return nil
		}
	}
}

class ConcreteEditorTheme: NSObject, EditorTheme
{
	fileprivate init(fromSerialized dict: [String: AnyObject])
	{
		name = (dict[kThemeNameKey] as? String) ?? "(Unamed)"
		windowBackground		= (dict[kThemeWindowBackgroundKey] as? NSColor) ?? NSColor(rgb: 0xFDFDFD)
		editorForeground		= (dict[kThemeEditorForegroundKey] as? NSColor) ?? NSColor.black
		editorBackground		= (dict[kThemeEditorBackgroundKey] as? NSColor) ?? NSColor.clear
		lineCounterForeground	= (dict[kThemeLineCounterForegroundKey] as? NSColor) ?? NSColor(rgb: 0x999999)
		lineCounterBackground	= (dict[kThemeLineCounterBackgroundKey] as? NSColor) ?? NSColor(rgb: 0xF5F5F5)
	}
	
	var name: String
	dynamic var windowBackground: NSColor
	dynamic var editorForeground: NSColor
	dynamic var editorBackground: NSColor
	dynamic var lineCounterForeground: NSColor
	dynamic var lineCounterBackground: NSColor

	dynamic var willDeallocate: Bool = false

	var preferenceName: String?
	{
		return "\(kThemeNativeNamePrefix)\(name)"
	}

	func makeCustom() -> EditorTheme?
	{
		return UserEditorTheme(customizingTheme: self)
	}
}

class UserEditorTheme : ConcreteEditorTheme
{
	private var fileWriterTimer: Timer? = nil

	var isCustomization: Bool
	{
		return name.hasSuffix("(Custom)")
	}

	private var fileURL: URL?
	{
		if let themesDirectory = UserEditorTheme.URLForUserThemesDirectory()
		{
			return themesDirectory.appendingPathComponent(name).appendingPathExtension("plist")
		}
		else
		{
			return nil
		}
	}

	init(customizingTheme originalTheme: EditorTheme)
	{
		let newName = originalTheme.name.appending(" (Custom)")

		super.init(fromSerialized: originalTheme.serialized)

		name = newName

		writeToFile(immediatelly: true)
	}

	init?(fromFile fileURL: URL)
	{
		if fileURL.isFileURL, var themeDictionary = NSDictionary(contentsOf: fileURL) as? [String : AnyObject]
		{
			for itemKey in UserEditorTheme.userThemeKeys
			{
				if themeDictionary[itemKey] == nil
				{
					return nil
				}

				if let intValue = themeDictionary[itemKey] as? UInt
				{
					themeDictionary[itemKey] = NSColor(rgba: intValue)
				}
			}

			super.init(fromSerialized: themeDictionary)

			name = fileURL.deletingPathExtension().lastPathComponent
		}
		else
		{
			return nil
		}
	}

	override var preferenceName: String?
	{
		if let fileURL = self.fileURL
		{
			return "\(kThemeUserNamePrefix)\(fileURL.path)"
		}

		return nil
	}

	override func didChangeValue(forKey key: String)
	{
		super.didChangeValue(forKey: key)

		writeToFile(immediatelly: false)
	}

	func writeToFile(immediatelly: Bool)
	{
		if immediatelly
		{
			writeToFileNow()
			fileWriterTimer?.invalidate()
			fileWriterTimer = nil
		}
		else
		{
			if let timer = self.fileWriterTimer
			{
				timer.fireDate = Date().addingTimeInterval(3)
			}
			else
			{
				fileWriterTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false)
				{
					(timer) in

					self.writeToFileNow()
					self.fileWriterTimer = nil
				}
			}
		}
	}

	private func writeToFileNow()
	{
		if let url = self.fileURL
		{
			let serialized = self.serialized
			let dict = (serialized as NSDictionary).mutableCopy() as! NSMutableDictionary

			for settingKey in serialized.keys
			{
				if let color = dict[settingKey] as? NSColor
				{
					dict.setValue(color.rgba, forKey: settingKey)
				}
			}

			dict.write(to: url, atomically: true)
		}
	}
}

protocol NativeEditorTheme {}

class LightEditorTheme: EditorTheme, NativeEditorTheme
{
	var name: String
	{
		return "Light"
	}
	
	var windowBackground: NSColor
	{
		return NSColor(rgb: 0xFDFDFD)
	}
	
	var editorForeground: NSColor
	{
		return NSColor.black
	}
	
	var editorBackground: NSColor
	{
		return NSColor.clear
	}
	
	var lineCounterForeground: NSColor
	{
		return NSColor(rgb: 0x999999)
	}
	
	var lineCounterBackground: NSColor
	{
		return NSColor(rgb: 0xF5F5F5)
	}

	var preferenceName: String?
	{
		return "\(kThemeNativeNamePrefix)\(name)"
	}
}