package org.uqbar.project.wollok.ui.console

import org.eclipse.ui.console.IHyperlink
import org.eclipse.ui.console.IPatternMatchListenerDelegate
import org.eclipse.ui.console.PatternMatchEvent
import org.eclipse.ui.console.TextConsole
import org.eclipse.xtext.ui.editor.IURIEditorOpener
import org.uqbar.project.wollok.ui.WollokActivator
import org.uqbar.project.wollok.ui.tests.AbstractWollokFileOpenerStrategy

import static extension org.uqbar.project.wollok.utils.WEclipseUtils.*
import static extension org.uqbar.project.wollok.ui.console.highlight.AnsiUtils.*

/**
 * Intended as an observer of REPL console: searches for a "(fileName:lineNumber)"
 * pattern and creates a hyperlink to that file, opening Wollok editor.
 * Reuses same behavior as test stack trace.
 * 
 * @author dodain
 * based on 
 */
class WollokLinkListenerDelegate implements IPatternMatchListenerDelegate {

	IURIEditorOpener opener
	TextConsole console

	override connect(TextConsole console) {
		this.console = console
		this.opener = WollokActivator.getInstance.opener
	}

	override disconnect() {
		this.console = null
	}

	override matchFound(PatternMatchEvent event) {
		try {
			val fileReferenceText = console.document.get(event.offset + 0, event.length)
			val hyperlink = makeHyperlink(fileReferenceText, opener) // a link to any file
			if (fileReferenceText.length == 0) return;
			val referenceDataLength = fileReferenceText.getReferenceData.length
			val margin = fileReferenceText.length - referenceDataLength
			console.addHyperlink(hyperlink, event.offset + margin, referenceDataLength)
		} catch (Exception exception) {
			throw new RuntimeException(exception)
		}
	}

	def static IHyperlink makeHyperlink(String fileReferenceText, IURIEditorOpener opener) {
		return new IHyperlink() {

			override linkExited() {}

			override linkEntered() {}

			override linkActivated() {
				try {
					val project = openProjects.head
					var referenceData = fileReferenceText.getReferenceData
					val fileOpenerStrategy = AbstractWollokFileOpenerStrategy.buildOpenerStrategy(referenceData,
						project)
					val textEditor = fileOpenerStrategy.getTextEditor(opener)
					val fileName = fileOpenerStrategy.fileName
					val Integer lineNumber = fileOpenerStrategy.lineNumber
					textEditor.openEditor(fileName, lineNumber)
				} catch (Exception exception) {
					throw new RuntimeException(exception)
				}
			}

		}
	}

	def static getReferenceData(String fileReferenceText) {
		var data = fileReferenceText.deleteAnsiCharacters.trim
		val firstParenthesis = data.lastIndexOf("(")
		if (firstParenthesis > 0) {
			data = data.substring(firstParenthesis)
		}
		if (data.startsWith("(")) {
			data = data.substring(1)
		}
		data
	}

}
