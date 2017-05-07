//
//  DocumentWindow.swift
//  Noto
//
//  Created by Bruno Philipe on 21/2/17.
//  Copyright © 2017 Bruno Philipe. All rights reserved.
//  
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Cocoa

@IBDesignable
class DocumentWindow: NSWindow
{
	private var infoBarController: InfoBar? = nil
	private var infoBarConstraints: [NSLayoutConstraint]? = nil
	private var defaultTopThemeConstraint: NSLayoutConstraint? = nil
	private var customTopThemeConstraint: NSLayoutConstraint? = nil

	@IBOutlet var textView: EditorView!
	@IBOutlet var textEditorBottomConstraint: NSLayoutConstraint!
	@IBOutlet var titleBarSeparatorView: BackgroundView!
	@IBOutlet var textEditorTopConstraint: NSLayoutConstraint!

	private let observedPreferences = [
			"editorFont", "editorThemeName", "smartSubstitutionsOn", "spellingCheckerOn", "tabSize", "useSpacesForTabs",
			"infoBarMode", "countWhitespacesInTotalCharacters", "showsInvisibles", "keepIndentationOnNewLines"
	]

	private let observedThemeSettings = [
			"editorBackground", "editorForeground", "lineCounterBackground", "lineCounterForeground", "willDeallocate"
	]

	var text: String
	{
		get
		{
			return textView.string ?? ""
		}

		set
		{
			textView.string = newValue
			updateInfoBar()
		}
	}

	override var toolbar: NSToolbar?
	{
		willSet
		{
			if let toolbar = self.toolbar
			{
				toolbar.removeObserver(self, forKeyPath: "dynamicIsVisible")
			}
		}

		didSet
		{
			if let toolbar = self.toolbar
			{
				toolbar.addObserver(self, forKeyPath: "dynamicIsVisible", options: .new, context: nil)
			}
		}
	}

	func setup(_ document: Document)
	{
		for observedPreference in observedPreferences
		{
			Preferences.instance.addObserver(self, forKeyPath: observedPreference, options: .new, context: nil)
		}

		setupWindowStyle()

		self.setupInfoBar()

		self.updateEditorFont()
		self.updateEditorColors()
		self.updateEditorSubstitutions()
		self.updateEditorSpellingCheck()
		self.updateEditorInvisibles()
		self.updateEditorTabSize()
		self.updateEditorSpacesForTabsOption()
		self.updateEditorKeepIndentsSetting()
		self.setupThemeObserver()

		self.textView.undoManager?.removeAllActions()
	}

	deinit
	{
		if let toolbar = self.toolbar
		{
			toolbar.removeObserver(self, forKeyPath: "dynamicIsVisible")
		}

		for observedPreference in observedPreferences
		{
			Preferences.instance.removeObserver(self, forKeyPath: observedPreference)
		}

		removeThemeObserver()
	}

	@IBAction func jumpToALine(_ sender: Any?)
	{
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = "Go to line:"
		alert.addButton(withTitle: "Go")
		alert.addButton(withTitle: "Cancel")

		let textField = NSTextField()
		textField.frame = NSMakeRect(0, 0, 90, 22)
		alert.accessoryView = textField

		alert.beginSheetModal(for: self)
		{
			response in

			if response == NSAlertFirstButtonReturn
			{
				if !self.textView.jumpToLine(lineNumber: textField.integerValue)
				{
					let warning = NSAlert()
					warning.alertStyle = .warning
					warning.messageText = "No such line “\(textField.stringValue)”."
					warning.addButton(withTitle: "OK")

					warning.beginSheetModal(for: self)
				}
			}
		}

		alert.window.makeFirstResponder(textField)
	}

	@IBAction func toggleShowInvisibles(_ sender: Any?)
	{
		Preferences.instance.showsInvisibles.flip()
	}

	@IBAction func toggleLinesCounter(_ sender: Any?)
	{
		if let scrollView = textView.enclosingScrollView
		{
			scrollView.rulersVisible.flip()
		}
	}

	private func setupThemeObserver()
	{
		let theme = Preferences.instance.editorTheme

		if let themeObject = theme as? ConcreteEditorTheme
		{
			for themeSetting in observedThemeSettings
			{
				themeObject.addObserver(self, forKeyPath: themeSetting, options: .new, context: nil)
			}
		}
	}

	private func removeThemeObserver()
	{
		let theme = Preferences.instance.editorTheme

		if let themeObject = theme as? ConcreteEditorTheme
		{
			for themeSetting in observedThemeSettings
			{
				themeObject.removeObserver(self, forKeyPath: themeSetting)
			}
		}
	}

	private func setupWindowStyle()
	{
		titlebarAppearsTransparent = true

		updateWindowToolbarStyle()

		minSize = NSSize(width: 300, height: 200)
	}

	private func setupInfoBar()
	{
		if let infoBarConstraints = self.infoBarConstraints
		{
			NSLayoutConstraint.deactivate(infoBarConstraints)
			self.infoBarConstraints = nil
		}

		if let viewController = infoBarController as? NSViewController
		{
			viewController.view.removeFromSuperview()
			self.infoBarController = nil
		}

		switch Preferences.instance.infoBarMode
		{
		case .hud:
			let infoBarController = HUDInfoBarController.make()
			let infoBar = infoBarController.view

			if let contentView = self.contentView
			{
				infoBar.translatesAutoresizingMaskIntoConstraints = false
				contentView.addSubview(infoBar)

				var constraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[infoBar]-16-|",
																 metrics: nil,
																 views: ["infoBar": infoBar])

				constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|-(>=30)-[infoBar]-(>=20)-|",
																			  metrics: nil,
																			  views: ["infoBar": infoBar]))

				constraints.append(NSLayoutConstraint(item: contentView,
													  attribute: .centerX,
													  relatedBy: .equal,
													  toItem: infoBar,
													  attribute: .centerX,
													  multiplier: 1.0,
													  constant: 0.0))

				infoBarConstraints = constraints

				NSLayoutConstraint.activate(constraints)

				self.infoBarController = infoBarController

				textView.delegate = self
				textEditorBottomConstraint.constant = 0
			}

		case .status:
			let infoBarController = StatusInfoBarController.make()
			let infoBar = infoBarController.view

			if let contentView = self.contentView
			{
				infoBar.translatesAutoresizingMaskIntoConstraints = false
				contentView.addSubview(infoBar)

				var constraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[infoBar]-0-|",
																 metrics: nil,
																 views: ["infoBar": infoBar])

				constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[infoBar]-0-|",
																			  metrics: nil,
																			  views: ["infoBar": infoBar]))

				infoBarConstraints = constraints

				NSLayoutConstraint.activate(constraints)

				self.infoBarController = infoBarController

				textView.delegate = self
				textEditorBottomConstraint.constant = infoBar.bounds.height
			}

		default:
			textView.delegate = nil
			textEditorBottomConstraint.constant = 0
			break
		}

		updateEditorColors()
		updateInfoBar()
	}

	fileprivate func updateInfoBar()
	{
		if let infoBar = self.infoBarController, let string = self.textView.string
		{
			var characterCount = Int(0)
			var wordsCount = Int(0)
			var linesCount = Int(1)

			if Preferences.instance.countWhitespacesInTotalCharacters
			{
				characterCount = string.characters.count
			}
			else
			{
				let whitespaceCharacterSet = NSCharacterSet.whitespacesAndNewlines

				string.characters.forEach
				{
					character in

					if String(character).rangeOfCharacter(from: whitespaceCharacterSet) == nil
					{
						characterCount += 1
					}
				}
			}

			string.enumerateSubstrings(in: string.fullStringRange, options: .byWords, { _ in wordsCount += 1 })
			string.enumerateSubstrings(in: string.fullStringRange, options: .byLines, { _ in linesCount += 1 })

			infoBar.setCharactersCount("\(characterCount) Character\(characterCount == 1 ? "" : "s")")
			infoBar.setWordsCount("\(wordsCount) Word\(wordsCount == 1 ? "" : "s")")
			infoBar.setLinesCount("\(linesCount) Line\(linesCount == 1 ? "" : "s")")
			infoBar.setEncoding((delegate as? Document)?.encoding.description ?? "<error>")
		}
	}

	override func observeValue(forKeyPath keyPath: String?,
							   of object: Any?,
							   change: [NSKeyValueChangeKey: Any]?,
							   context: UnsafeMutableRawPointer?)
	{
		textView.undoManager?.disableUndoRegistration()

		if object is Preferences
		{
			switch keyPath
			{
			case .some("editorFont"):
				updateEditorFont()

			case .some("editorThemeName"):
				updateEditorColors()
				setupThemeObserver()

			case .some("smartSubstitutionsOn"):
				updateEditorSubstitutions()

			case .some("spellingCheckerOn"):
				updateEditorSpellingCheck()

			case .some("tabSize"):
				updateEditorTabSize()

			case .some("useSpacesForTabs"):
				updateEditorSpacesForTabsOption()

			case .some("infoBarMode"):
				setupInfoBar()

			case .some("countWhitespacesInTotalCharacters"):
				updateInfoBar()

			case .some("showsInvisibles"):
				updateEditorInvisibles()

			case .some("keepIndentationOnNewLines"):
				updateEditorKeepIndentsSetting()

			default:
				break
			}
		}
		else if object is EditorTheme
		{
			switch keyPath
			{
			case .some("willDeallocate"):
				removeThemeObserver()

			case .some(_):
				updateEditorColors()

			default:
				break
			}
		}
		else if object is NSToolbar
		{
			switch keyPath
			{
			case .some("dynamicIsVisible"):
				updateWindowToolbarStyle()

			default:
				break
			}
		}

		textView.undoManager?.enableUndoRegistration()
	}

	private func updateWindowToolbarStyle()
	{
		let visible = (toolbar?.isVisible ?? false)

		if let contentView = self.contentView as? PullableContentView
		{
			contentView.pullsContent = !visible
		}

		textView.textContainerInset = NSSize(width: textView.textContainerInset.width, height: visible ? 10 : 32)

		titleBarSeparatorView.isHidden = !visible

		if let contentView = self.contentView
		{
			contentView.setFrameSize(NSSize(width: contentView.frame.size.width,
											height: contentView.frame.size.height - (visible ? 22.0 : 0.0)))
		}
	}

	private func updateEditorFont()
	{
		textView.font = Preferences.instance.editorFont

		updateEditorTabSize()
	}

	private func updateEditorColors()
	{
		let theme = Preferences.instance.editorTheme
		let isDark = theme.editorBackground.isDarkColor

		appearance = isDark ? NSAppearance(named:NSAppearanceNameVibrantDark)
							: NSAppearance(named:NSAppearanceNameVibrantLight)

		if let hudController = infoBarController as? HUDInfoBarController
		{
			hudController.setDarkMode(!isDark)
		}
		else if let statusController = infoBarController as? StatusInfoBarController
		{
			statusController.setTextColor(theme.lineCounterForeground)
			statusController.setBackgroundColor(theme.lineCounterBackground)
		}

		backgroundColor = theme.editorBackground
		textView.setColorsFromTheme(theme: theme)
	}
	
	private func updateEditorSubstitutions()
	{
		let enabled = Preferences.instance.smartSubstitutionsOn
		
		textView.isAutomaticDashSubstitutionEnabled = enabled
		textView.isAutomaticQuoteSubstitutionEnabled = enabled
		textView.smartInsertDeleteEnabled = enabled
	}
	
	private func updateEditorSpellingCheck()
	{
		let enabled = Preferences.instance.spellingCheckerOn
		
		textView.isContinuousSpellCheckingEnabled = enabled
		textView.isAutomaticSpellingCorrectionEnabled = enabled
	}

	private func updateEditorInvisibles()
	{
		let enabled = Preferences.instance.showsInvisibles

		textView.showsInvisibleCharacters = enabled
	}

	private func updateEditorTabSize()
	{
		textView.setTabWidth(Preferences.instance.tabSize)
	}

	private func updateEditorSpacesForTabsOption()
	{
		textView.usesSpacesForTabs = Preferences.instance.useSpacesForTabs
	}

	private func updateEditorKeepIndentsSetting()
	{
		textView.keepsIndentationOnNewLines = Preferences.instance.keepIndentationOnNewLines
	}
}

extension DocumentWindow: NSTextViewDelegate
{
	func textDidChange(_ notification: Notification)
	{
		self.updateInfoBar()
	}
}

extension DocumentWindow
{
	func encodingDidChange(document: Document, newEncoding: String.Encoding)
	{
		self.updateInfoBar()
	}
}
