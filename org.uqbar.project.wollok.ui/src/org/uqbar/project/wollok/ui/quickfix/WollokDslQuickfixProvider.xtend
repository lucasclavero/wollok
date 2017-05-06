package org.uqbar.project.wollok.ui.quickfix

import com.google.inject.Inject
import java.util.List
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.ui.editor.model.IXtextDocument
import org.eclipse.xtext.ui.editor.model.edit.IModificationContext
import org.eclipse.xtext.ui.editor.quickfix.DefaultQuickfixProvider
import org.eclipse.xtext.ui.editor.quickfix.Fix
import org.eclipse.xtext.ui.editor.quickfix.IssueResolutionAcceptor
import org.eclipse.xtext.ui.editor.utils.EditorUtils
import org.eclipse.xtext.ui.refactoring.ui.IRenameContextFactory
import org.eclipse.xtext.ui.refactoring.ui.IRenameElementContext
import org.eclipse.xtext.ui.refactoring.ui.IRenameSupport
import org.eclipse.xtext.util.concurrent.IUnitOfWork
import org.eclipse.xtext.validation.Issue
import org.uqbar.project.wollok.interpreter.WollokClassFinder
import org.uqbar.project.wollok.ui.Messages
import org.uqbar.project.wollok.validation.WollokDslValidator
import org.uqbar.project.wollok.wollokDsl.WAssignment
import org.uqbar.project.wollok.wollokDsl.WBlockExpression
import org.uqbar.project.wollok.wollokDsl.WClass
import org.uqbar.project.wollok.wollokDsl.WConstructor
import org.uqbar.project.wollok.wollokDsl.WExpression
import org.uqbar.project.wollok.wollokDsl.WIfExpression
import org.uqbar.project.wollok.wollokDsl.WMemberFeatureCall
import org.uqbar.project.wollok.wollokDsl.WMethodContainer
import org.uqbar.project.wollok.wollokDsl.WMethodDeclaration
import org.uqbar.project.wollok.wollokDsl.WVariableDeclaration
import org.uqbar.project.wollok.wollokDsl.WVariableReference
import org.uqbar.project.wollok.wollokDsl.WollokDslFactory
import org.uqbar.project.wollok.wollokDsl.WollokDslPackage

import static org.uqbar.project.wollok.WollokConstants.*
import static org.uqbar.project.wollok.validation.WollokDslValidator.*

import static extension org.uqbar.project.wollok.model.WMethodContainerExtensions.*
import static extension org.uqbar.project.wollok.model.WollokModelExtensions.*
import static extension org.uqbar.project.wollok.ui.quickfix.QuickFixUtils.*
import static extension org.uqbar.project.wollok.utils.XTextExtensions.*

/**
 * Custom quickfixes.
 * see https://eclipse.org/Xtext/documentation/310_eclipse_support.html#quick-fixes
 * 
 * @author jfernandes
 * @author tesonep
 * @author dodain
 */
class WollokDslQuickfixProvider extends DefaultQuickfixProvider {
	val tabChar = "\t"
	val blankSpace = " "
	val returnChar = System.lineSeparator

	@Inject
	WollokClassFinder classFinder

	@Inject(optional=true)
	IRenameSupport.Factory renameSupportFactory

	@Inject(optional=true)
	IRenameContextFactory renameContextFactory

	/** 
	 * ***********************************************************************
	 * 					     Capitalization & Lowercase
	 * ***********************************************************************
	 */
	@Fix(WollokDslValidator.CLASS_NAME_MUST_START_UPPERCASE)
	def capitalizeName(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_capitalize_name,
			Messages.WollokDslQuickfixProvider_capitalize_description, null) [ e, it |
			
			val firstLetter = xtextDocument.get(issue.offset, 1)
			val newText = firstLetter.toUpperCase
			xtextDocument.replace(issue.offset, 1, newText)
			for (INode node : e.node.rootNode.leafNodes) {
				if (e.applyRenameTo(node)) {
					println("        AJA :::: " + node.semanticElement)
					xtextDocument => [
						replace(node.offset, 1, newText)
					]
				}
			}
				
//			val rename = renameSupportFactory.create(xtextDocument.renameElementContext(e), e.name.upperCaseName)
//			rename.startDirectRefactoring
		]
	}

	@Fix(WollokDslValidator.PARAMETER_NAME_MUST_START_LOWERCASE)
	def toLowerCaseParameterName(Issue issue, IssueResolutionAcceptor acceptor) {
		toLowerCaseReferenciableName(issue, acceptor)
	}

	@Fix(WollokDslValidator.OBJECT_NAME_MUST_START_LOWERCASE)
	def toLowerCaseObjectName(Issue issue, IssueResolutionAcceptor acceptor) {
		toLowerCaseReferenciableName(issue, acceptor)
	}

	@Fix(WollokDslValidator.VARIABLE_NAME_MUST_START_LOWERCASE)
	def toLowerCaseVariableName(Issue issue, IssueResolutionAcceptor acceptor) {
		toLowerCaseReferenciableName(issue, acceptor)
	}

	@Fix(WollokDslValidator.REFERENCIABLE_NAME_MUST_START_LOWERCASE)
	def toLowerCaseReferenciableName(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_lowercase_name,
			Messages.WollokDslQuickfixProvider_lowercase_description, null) [ e, it |

			//https://www.eclipse.org/forums/index.php/t/485483/
			val firstLetter = xtextDocument.get(issue.offset, 1)
			val newText = firstLetter.toLowerCase
			xtextDocument.replace(issue.offset, 1, newText)
			for (INode node : e.node.rootNode.leafNodes) {
				if (e.applyRenameTo(node)) {
					println("        AJA :::: " + node.semanticElement)
					xtextDocument => [
						replace(node.offset, 1, newText)
					]
				}
			}


//			val rename = renameSupportFactory.create(xtextDocument.renameElementContext(e), e.name.lowerCaseName)
//			rename.startDirectRefactoring
		]
	}

	/** 
	 * ***********************************************************************
	 * 							Constructors
	 * ***********************************************************************
	 */
	@Fix(WollokDslValidator.REQUIRED_SUPERCLASS_CONSTRUCTOR)
	def addConstructorsFromSuperclass(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_add_constructors_superclass_name,
			Messages.WollokDslQuickFixProvider_add_constructors_superclass_description, null) [ e, it |
			val clazz = e as WClass
			val constructors = clazz.parent.constructors.map [
				'''«tabChar»constructor(«parameters.map[name].join(',')») = super(«parameters.map[name].join(',')»)«returnChar»'''
			].join(System.lineSeparator)
			addMethod(clazz, constructors)
		]
	}

	@Fix(CONSTRUCTOR_IN_SUPER_DOESNT_EXIST)
	def createConstructorInSuperClass(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_create_constructor_superclass_name,
			Messages.WollokDslQuickFixProvider_create_constructor_superclass_description, null) [ e, it |
			val delegatingConstructor = (e as WConstructor).delegatingConstructorCall
			val parent = e.wollokClass.parent

			val constructor = '''
				«tabChar»constructor(«(1..delegatingConstructor.arguments.size).map["param" + it].join(",")»){
				«tabChar»«tabChar»//TODO: «Messages.WollokDslQuickfixProvider_createMethod_stub»
				«tabChar»}
			'''

			addMethod(parent, constructor)
		]
	}

	@Fix(DUPLICATED_CONSTRUCTOR)
	def deleteDuplicatedConstructor(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_constructor_name,
			Messages.WollokDslQuickFixProvider_remove_constructor_description, null) [ e, it |
			xtextDocument.delete(e)
		]
	}

	@Fix(MUST_CALL_SUPER)
	def addCallToSuperInConstructor(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_add_call_super_name,
			Messages.WollokDslQuickFixProvider_add_call_super_description, null) [ e, it |
			val const = e as WConstructor
			val call = " = super()" // this could be more involved here and useful for the user :P
			val paramCloseOffset = const.node.text.indexOf(")")
			xtextDocument.replace(e.before + paramCloseOffset - 1, 0, call)
		]
	}

	/** 
	 * ***********************************************************************
	 * 							Getters
	 * ***********************************************************************
	 */
	@Fix(WollokDslValidator.GETTER_METHOD_SHOULD_RETURN_VALUE)
	def addReturnVariable(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_return_variable_name,
			Messages.WollokDslQuickfixProvider_return_variable_description, null) [ e, context |
			val method = e as WMethodDeclaration
			if (!method.expressionReturns) {
				val body = method.expression as WBlockExpression
				if (body.expressions.empty) {
					context.xtextDocument.replaceWith(body,
						"{" + System.lineSeparator + "\t\t" + RETURN + " " + method.name + System.lineSeparator + "\t}")
				} else
					context.insertAfter(body.expressions.last, RETURN + " " + method.name)
			}
		]
	}

	@Fix(WollokDslValidator.CANNOT_ASSIGN_TO_VAL)
	def changeDeclarationToVar(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_changeToVar_name,
			Messages.WollokDslQuickfixProvider_changeToVar_description, null) [ e, context |
			val f = (e as WAssignment).feature.ref.eContainer
			if (f instanceof WVariableDeclaration) {
				val feature = f as WVariableDeclaration
				context.xtextDocument.replace(feature.before, feature.node.length,
					VAR + " " + feature.variable.name + " =" + feature.right.node.text)
			}
		]
	}

	@Fix(WollokDslValidator.METHOD_ON_WKO_DOESNT_EXIST)
	def createNonExistingMethodOnWKO(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_createMethod_name,
			Messages.WollokDslQuickfixProvider_createMethod_description, null) [ e, context |
			val call = e as WMemberFeatureCall
			val callText = call.node.text

			val wko = call.resolveWKO(classFinder)

			val placeToAdd = wko.findPlaceToAddMethod

			context.getXtextDocument(wko.fileURI).replace(
				placeToAdd,
				0,
				System.lineSeparator + "\t" + METHOD + " " + call.feature +
					callText.substring(callText.indexOf('('), callText.lastIndexOf(')') + 1) + " {" +
					System.lineSeparator + "\t\t//TODO: " + Messages.WollokDslQuickfixProvider_createMethod_stub +
					System.lineSeparator + "\t}"
			)
		]
	}

	@Fix(WollokDslValidator.METHOD_ON_THIS_DOESNT_EXIST)
	def createNonExistingMethodOnSelf(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_createMethod_name,
			Messages.WollokDslQuickfixProvider_createMethod_description, null) [ e, context |
			val call = e as WMemberFeatureCall
			val callText = call.node.text

			val selfContainer = call.method.eContainer as WMethodContainer

			val placeToAdd = selfContainer.findPlaceToAddMethod

			context.getXtextDocument(selfContainer.fileURI).replace(
				placeToAdd,
				0,
				System.lineSeparator + System.lineSeparator + "\t" + METHOD + " " + call.feature +
					callText.substring(callText.indexOf('('), callText.lastIndexOf(')') + 1) + " {" +
					System.lineSeparator + "\t\t//TODO: " + Messages.WollokDslQuickfixProvider_createMethod_stub +
					System.lineSeparator + "\t}"
			)
		]
	}

	@Fix(WollokDslValidator.METHOD_MUST_HAVE_OVERRIDE_KEYWORD)
	def changeDefToOverride(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_add_override_name,
			Messages.WollokDslQuickfixProvider_add_override_description, null) [ e, it |
			xtextDocument.prepend(e, OVERRIDE + ' ')
		]
	}

	@Fix(CANT_OVERRIDE_FROM_BASE_CLASS)
	def removeOverrideKeywordFromBaseClass(Issue issue, IssueResolutionAcceptor acceptor) {
		removeOverrideKeyword(issue, acceptor)
	}

	@Fix(METHOD_DOESNT_OVERRIDE_ANYTHING)
	def addMethodToSuperClass(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_create_method_superclass_name,
			Messages.WollokDslQuickfixProvider_create_method_superclass_description, null) [ e, it |
			val method = e as WMethodDeclaration
			val container = method.eContainer as WMethodContainer
			addMethod(container.parent, defaultStubMethod(container.parent, method))
		]
	}

	@Fix(METHOD_DOESNT_OVERRIDE_ANYTHING)
	def removeOverrideKeyword(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_override_keyword_name,
			Messages.WollokDslQuickFixProvider_remove_override_keyword_description, null) [ e, it |
			xtextDocument.deleteToken(e, OVERRIDE + blankSpace)
		]
	}

	// TODO, No tenemos que hacerlo
	/** 
	 * ***********************************************************************
	 * 							Unused abstractions
	 * ***********************************************************************
	 */
	@Fix(WollokDslValidator.WARNING_UNUSED_VARIABLE)
	def removeUnusedVariable(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_unused_variable_name,
			Messages.WollokDslQuickFixProvider_remove_unused_variable_description, null) [ e, it |
			xtextDocument.delete(e)
		]
	}

	@Fix(NATIVE_METHOD_CANNOT_OVERRIDES)
	def removeOverrideFromNativeMethod(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_override_keyword_name,
			Messages.WollokDslQuickFixProvider_remove_override_keyword_description, null) [ e, it |
			xtextDocument.deleteToken(e, OVERRIDE)
		]
	}

	@Fix(DUPLICATED_METHOD)
	def removeDuplicatedMethod(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_remove_method_name,
			Messages.WollokDslQuickFixProvider_remove_method_description, null) [ e, it |
			xtextDocument.delete(e)
		]
	}

	@Fix(VARIABLE_NEVER_ASSIGNED)
	def initializeNonAssignedVariable(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_initialize_value_name,
			Messages.WollokDslQuickFixProvider_initialize_value_description, null) [ e, it |
			xtextDocument.append(e, " = value")
		]
	}

	@Fix(WollokDslValidator.ERROR_TRY_WITHOUT_CATCH_OR_ALWAYS)
	def addCatchOrAlwaysToTry(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_add_catch_name,
			Messages.WollokDslQuickFixProvider_add_catch_description, null) [ e, context |
			context.insertAfter(
				e,
				'''
				catch e : wollok.lang.Exception {
					// TODO: «Messages.WollokDslQuickfixProvider_createMethod_stub»
					throw e
				}'''
			)
		]

		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_add_always_name,
			Messages.WollokDslQuickFixProvider_add_always_name, null) [ e, context |
			context.insertAfter(
				e,
				'''
				then always {
					//TODO: «Messages.WollokDslQuickfixProvider_createMethod_stub»
				}'''
			)
		]
	}

	@Fix(BAD_USAGE_OF_IF_AS_BOOLEAN_EXPRESSION)
	def wrongUsageOfIfForBooleanExpressions(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickFixProvider_replace_if_condition_name,
			Messages.WollokDslQuickFixProvider_replace_if_condition_description, null) [ e, it |
			val ifE = e as WIfExpression
			var inlineResult = if (ifE.then.isReturnTrue)
					ifE.condition.sourceCode
				else
					("!(" + ifE.condition.sourceCode + ")")
			if (ifE.then.hasReturnWithValue) {
				inlineResult = RETURN + " " + inlineResult
			}
			xtextDocument.replaceWith(e, inlineResult)
		]
	}

	@Fix(RETURN_FORGOTTEN)
	def prependReturn(Issue issue, IssueResolutionAcceptor acceptor) {
		acceptor.accept(issue, Messages.WollokDslQuickfixProvider_return_last_expression_name,
			Messages.WollokDslQuickfixProvider_return_last_expression_description, null) [ e, it |
			val method = e as WMethodDeclaration
			val body = (method.expression as WBlockExpression)
			if (!body.expressions.empty)
				insertBefore(body.expressions.last, RETURN + " ")
		]
	}

	@Fix(GETTER_METHOD_SHOULD_RETURN_VALUE)
	def prependReturnForGetter(Issue issue, IssueResolutionAcceptor acceptor) {
		prependReturn(issue, acceptor)
	}

	// ************************************************
	// ** unresolved ref to "elements" quick fixes
	// ************************************************
	protected def quickFixForUnresolvedRefToVariable(IssueResolutionAcceptor issueResolutionAcceptor, Issue issue,
		IXtextDocument xtextDocument, EObject target) {
		// issue #452 - contextual menu based on different targets
		val targetContext = target.getSelfContext
		val hasMethodContainer = targetContext !== null
		val hasParameters = target.declaringMethod !== null && target.declaringMethod.parameters !== null
		val canCreateLocalVariable = target.canCreateLocalVariable

		// create local var
		if (canCreateLocalVariable) {
			issueResolutionAcceptor.accept(issue, Messages.WollokDslQuickFixProvider_create_local_variable_name,
				Messages.WollokDslQuickFixProvider_create_local_variable_description, "variable.gif") [ e, context |
				val newVarName = xtextDocument.get(issue.offset, issue.length)
				val firstExpressionInContext = e.firstExpressionInContext
				context.insertBefore(firstExpressionInContext, VAR + " " + newVarName)
			]
		}

		// create instance var
		if (hasMethodContainer) {
			issueResolutionAcceptor.accept(issue, Messages.WollokDslQuickFixProvider_create_instance_variable_name,
				Messages.WollokDslQuickFixProvider_create_instance_variable_description, "variable.gif") [ e, context |
				val newVarName = xtextDocument.get(issue.offset, issue.length)
				val declaringContext = e.declaringContext
				val firstClassChild = declaringContext.eContents.head
				context.insertBefore(firstClassChild, VAR + " " + newVarName)
			]
		}

		// create parameter
		if (hasParameters) {
			issueResolutionAcceptor.accept(issue, Messages.WollokDslQuickFixProvider_add_parameter_method_name,
				Messages.WollokDslQuickFixProvider_add_parameter_method_description, "variable.gif") [ e, context |
				val newVarName = xtextDocument.get(issue.offset, issue.length)
				val method = (e as WExpression).method
				method.parameters += (WollokDslFactory.eINSTANCE.createWParameter => [name = newVarName])
			]
		}
	}

	protected def quickFixForUnresolvedRefToClass(IssueResolutionAcceptor issueResolutionAcceptor, Issue issue,
		IXtextDocument xtextDocument) {
		// create local var
		issueResolutionAcceptor.accept(issue, Messages.WollokDslQuickFixProvider_create_new_class_name,
			Messages.WollokDslQuickFixProvider_create_new_class_description, "class.png") [ e, context |
			val newClassName = xtextDocument.get(issue.offset, issue.length)
			val container = (e as WExpression).method.declaringContext
			context.xtextDocument.replace(container.after, 0,
				System.lineSeparator + CLASS + newClassName + " {" + System.lineSeparator + "}" + System.lineSeparator)
		]

	}

	// *********************************************
	// ** Unresolved references code (should be generalized into something using reflection as xtext's declarative quickfixes)
	// **   this needs some overriding since xtext doesn't have an extension point or declarative way
	// **   to get in between (they already provide a quick fix to change the reference to some other similar variable name)
	// *********************************************
	override createLinkingIssueResolutions(Issue issue, IssueResolutionAcceptor issueResolutionAcceptor) {
		super.createLinkingIssueResolutions(issue, issueResolutionAcceptor)

		// adding "create for unresolved references"		
		val modificationContext = modificationContextFactory.createModificationContext(issue)
		val xtextDocument = modificationContext.xtextDocument
		if (xtextDocument === null)
			return;
		xtextDocument.readOnly(new IUnitOfWork.Void<XtextResource>() {
			override process(XtextResource state) throws Exception {
				val target = state.getEObject(issue.uriToProblem.fragment)
				val reference = getUnresolvedEReference(issue, target)
				if (reference === null)
					return;
				quickFixUnresolvedRef(target, reference, issueResolutionAcceptor, issue, xtextDocument)
			}
		})
	}

	protected def quickFixUnresolvedRef(EObject target, EReference reference,
		IssueResolutionAcceptor issueResolutionAcceptor, Issue issue, IXtextDocument xtextDocument) {
		if (target instanceof WVariableReference && reference.EType == WollokDslPackage.Literals.WREFERENCIABLE &&
			reference.name == "ref") {
			quickFixForUnresolvedRefToVariable(issueResolutionAcceptor, issue, xtextDocument, target)
		} else if (reference.EType == WollokDslPackage.Literals.WCLASS) {
			quickFixForUnresolvedRefToClass(issueResolutionAcceptor, issue, xtextDocument)
		}
	}

	/**
	 * *****************************************************************
	 *                         Internal methods
	 * *****************************************************************
	 */
	def defaultStubMethod(WClass clazz, WMethodDeclaration method) {
		val margin = adjustMargin(clazz)
		'''
		«margin»method «method.name»(«method.parameters.map[name].join(",")») {
		«margin»	//TODO: «Messages.WollokDslQuickfixProvider_createMethod_stub»
		«margin»}''' + System.lineSeparator
	}

	def adjustMargin(WClass clazz) {
		if(clazz.methods.empty) tabChar else ""
	}

	def resolveXtextDocumentFor(Issue issue) {
		modificationContextFactory.createModificationContext(issue).xtextDocument
	}

	protected def addMethod(IModificationContext it, WClass parent, String code) {
		val newContext = getContainerContext(it, parent)

		val lastConstructor = parent.members.findLast[it instanceof WConstructor]
		if (lastConstructor !== null)
			newContext.insertAfter(lastConstructor, code)
		else {
			val lastVar = parent.members.findLast[it instanceof WVariableDeclaration]
			if (lastVar !== null)
				newContext.insertAfter(lastVar, code)
			else {
				val firstMethod = parent.members.findFirst[it instanceof WMethodDeclaration]
				if (firstMethod !== null) {
					newContext.insertBefore(firstMethod, code)
				} else {
					newContext.xtextDocument.replace(parent.after - 1, 0, code)
				}
			}
		}
	}

	def getContainerContext(IModificationContext it, WClass parent) {
		new IModificationContext() {

			override getXtextDocument() {
				it.getXtextDocument(parent.fileURI)
			}

			override getXtextDocument(URI uri) {
				it.getXtextDocument(uri)
			}

		}
	}

	def int findPlaceToAddMethod(WMethodContainer it) {
		val lastMethod = members.lastOf(WMethodDeclaration)
		if (lastMethod !== null)
			return lastMethod.after
		val lastConstructor = members.lastOf(WConstructor)
		if (lastConstructor !== null)
			return lastConstructor.after
		val lastInstVar = members.lastOf(WVariableDeclaration)
		if (lastInstVar !== null)
			return lastInstVar.after

		return it.node.offset + it.node.text.indexOf("{") + 1
	}

	def <T> T lastOf(List<?> l, Class<T> type) { l.findLast[type.isInstance(it)] as T }

	def lowerCaseName(String name) {
		name.substring(0, 1).toLowerCase + name.substring(1, name.length)
	}

	def upperCaseName(String name) {
		name.substring(0, 1).toUpperCase + name.substring(1, name.length)
	}

	def renameElementContext(IXtextDocument xtextDocument, EObject e) {
		xtextDocument.modify(new IUnitOfWork<IRenameElementContext, XtextResource>() {
			override def IRenameElementContext exec(XtextResource state) {
				renameContextFactory.createRenameElementContext(e, EditorUtils.activeXtextEditor, null, state)
			}
		})
	}

}
