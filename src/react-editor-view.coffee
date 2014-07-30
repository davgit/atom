{View, $} = require 'space-pen'
React = require 'react-atom-fork'
{defaults} = require 'underscore-plus'
TextBuffer = require 'text-buffer'
Editor = require './editor'
EditorComponent = require './editor-component'
{deprecate} = require 'grim'

# Public: Represents the entire visual pane in Atom.
#
# The EditorView manages the {Editor}, which manages the file buffers.
#
# ## Requiring in packages
#
# ```coffee
# {EditorView} = require 'atom'
#
# miniEditorView = new EditorView(mini: true)
# ```
#
# ## Iterating over the open editor views
#
# ```coffee
# for editorView in atom.workspaceView.getEditorViews()
#   console.log(editorView.getEditor().getPath())
# ```
#
# ## Subscribing to every current and future editor
#
# ```coffee
# atom.workspace.eachEditorView (editorView) ->
#   console.log(editorView.getEditor().getPath())
# ```
module.exports =
class EditorView extends View
  @configDefaults:
    fontFamily: ''
    fontSize: 16
    lineHeight: 1.3
    showInvisibles: false
    showIndentGuide: false
    showLineNumbers: true
    autoIndent: true
    normalizeIndentOnPaste: true
    nonWordCharacters: "/\\()\"':,.;<>~!@#$%^&*|+=[]{}`?-"
    preferredLineLength: 80
    tabLength: 2
    softWrap: false
    softTabs: true
    softWrapAtPreferredLineLength: false
    scrollSensitivity: 40
    useHardwareAcceleration: true

  @content: (params) ->
    attributes = params.attributes ? {}
    attributes.class = 'editor react editor-colors'
    @div attributes

  focusOnAttach: false

  # The constructor for setting up an `EditorView` instance.
  #
  # editorOrParams - Either an {Editor}, or an object with one property, `mini`.
  #                  If `mini` is `true`, a "miniature" `Editor` is constructed.
  #                  Typically, this is ideal for scenarios where you need an Atom editor,
  #                  but without all the chrome, like scrollbars, gutter, _e.t.c._.
  #
  constructor: (editorOrParams, props) ->
    super

    if editorOrParams instanceof Editor
      @editor = editorOrParams
    else
      {@editor, @mini, placeholderText} = editorOrParams
      props ?= {}
      props.mini = @mini
      props.placeholderText = placeholderText
      @editor ?= new Editor
        buffer: new TextBuffer
        softWrap: false
        tabLength: 2
        softTabs: true

    props = defaults({@editor, parentView: this}, props)
    @component = React.renderComponent(EditorComponent(props), @element)

    node = @component.getDOMNode()

    @scrollView = $(node).find('.scroll-view')
    @underlayer = $(node).find('.highlights').addClass('underlayer')
    @overlayer = $(node).find('.lines').addClass('overlayer')
    @hiddenInput = $(node).find('.hidden-input')

    # FIXME: there should be a better way to deal with the gutter element
    @subscribe atom.config.observe 'editor.showLineNumbers', =>
      @gutter = $(node).find('.gutter')

      @gutter.removeClassFromAllLines = (klass) =>
        deprecate('Use decorations instead: http://blog.atom.io/2014/07/24/decorations.html')
        @gutter.find('.line-number').removeClass(klass)

      @gutter.getLineNumberElement = (bufferRow) =>
        deprecate('Use decorations instead: http://blog.atom.io/2014/07/24/decorations.html')
        @gutter.find("[data-buffer-row='#{bufferRow}']")

      @gutter.addClassToLine = (bufferRow, klass) =>
        deprecate('Use decorations instead: http://blog.atom.io/2014/07/24/decorations.html')
        lines = @gutter.find("[data-buffer-row='#{bufferRow}']")
        lines.addClass(klass)
        lines.length > 0

  getEditor: ->
    deprecate("Use EditorView::getModel instead")
    @editor

  # Public: Get the underlying editor model for this view.
  #
  # Returns an {Editor}.
  getModel: -> @editor

  Object.defineProperty @::, 'lineHeight', get: -> @editor.getLineHeightInPixels()
  Object.defineProperty @::, 'charWidth', get: -> @editor.getDefaultCharWidth()
  Object.defineProperty @::, 'firstRenderedScreenRow', get: -> @component.getRenderedRowRange()[0]
  Object.defineProperty @::, 'lastRenderedScreenRow', get: -> @component.getRenderedRowRange()[1]
  Object.defineProperty @::, 'active', get: -> @is(@getPane()?.activeView)
  Object.defineProperty @::, 'isFocused', get: -> @component?.state.focused

  afterAttach: (onDom) ->
    return unless onDom
    return if @attached
    @attached = true
    @component.pollDOM()
    @focus() if @focusOnAttach
    @trigger 'editor:attached', [this]

  scrollTop: (scrollTop) ->
    if scrollTop?
      @editor.setScrollTop(scrollTop)
    else
      @editor.getScrollTop()

  scrollLeft: (scrollLeft) ->
    if scrollLeft?
      @editor.setScrollLeft(scrollLeft)
    else
      @editor.getScrollLeft()

  # Public: Scrolls the editor to the bottom.
  scrollToBottom: ->
    @editor.setScrollBottom(Infinity)

  # Public: Scrolls the editor to the given screen position.
  #
  # screenPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - A hash matching the options available to {::scrollToScreenPosition}
  scrollToScreenPosition: (screenPosition, options) ->
    @editor.scrollToScreenPosition(screenPosition, options)

  # Public: Scrolls the editor to the given buffer position.
  #
  # bufferPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - A hash matching the options available to {::scrollToBufferPosition}
  scrollToBufferPosition: (bufferPosition, options) ->
    @editor.scrollToBufferPosition(bufferPosition, options)

  scrollToCursorPosition: ->
    @editor.scrollToCursorPosition()

  # Public: Converts a buffer position to a pixel position.
  #
  # position - An object that represents a buffer position. It can be either
  #            an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  #
  # Returns an object with two values: `top` and `left`, representing the pixel positions.
  pixelPositionForBufferPosition: (bufferPosition) ->
    @editor.pixelPositionForBufferPosition(bufferPosition)

  # Public: Converts a screen position to a pixel position.
  #
  # position - An object that represents a screen position. It can be either
  #            an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  #
  # Returns an object with two values: `top` and `left`, representing the pixel positions.
  pixelPositionForScreenPosition: (screenPosition) ->
    @editor.pixelPositionForScreenPosition(screenPosition)

  appendToLinesView: (view) ->
    view.css('position', 'absolute')
    view.css('z-index', 1)
    @find('.lines').prepend(view)

  beforeRemove: ->
    React.unmountComponentAtNode(@element) if @component.isMounted()
    @attached = false
    @trigger 'editor:detached', this

  # Public: Split the editor view left.
  splitLeft: ->
    pane = @getPane()
    pane?.splitLeft(pane?.copyActiveItem()).activeView

  # Public: Split the editor view right.
  splitRight: ->
    pane = @getPane()
    pane?.splitRight(pane?.copyActiveItem()).activeView

  # Public: Split the editor view up.
  splitUp: ->
    pane = @getPane()
    pane?.splitUp(pane?.copyActiveItem()).activeView

  # Public: Split the editor view down.
  splitDown: ->
    pane = @getPane()
    pane?.splitDown(pane?.copyActiveItem()).activeView

  # Public: Get this view's pane.
  #
  # Returns a {Pane}.
  getPane: ->
    @parent('.item-views').parents('.pane').view()

  focus: ->
    if @component?
      @component.onFocus()
    else
      @focusOnAttach = true

  hide: ->
    super
    @pollComponentDOM()

  show: ->
    super
    @pollComponentDOM()

  pollComponentDOM: ->
    return unless @component?
    valueToRestore = @component.performSyncUpdates
    @component.performSyncUpdates = true
    @component.pollDOM()
    @component.performSyncUpdates = valueToRestore

  pageDown: ->
    deprecate('Use editorView.getModel().pageDown()')
    @editor.pageDown()

  pageUp: ->
    deprecate('Use editorView.getModel().pageUp()')
    @editor.pageUp()

  # Public: Retrieves the number of the row that is visible and currently at the
  # top of the editor.
  #
  # Returns a {Number}.
  getFirstVisibleScreenRow: ->
    @editor.getVisibleRowRange()[0]

  # Public: Retrieves the number of the row that is visible and currently at the
  # bottom of the editor.
  #
  # Returns a {Number}.
  getLastVisibleScreenRow: ->
    @editor.getVisibleRowRange()[1]

  # Public: Gets the font family for the editor.
  #
  # Returns a {String} identifying the CSS `font-family`.
  getFontFamily: ->
    @component?.getFontFamily()

  # Public: Sets the font family for the editor.
  #
  # fontFamily - A {String} identifying the CSS `font-family`.
  setFontFamily: (fontFamily)->
    @component?.setFontFamily(fontFamily)

  # Public: Retrieves the font size for the editor.
  #
  # Returns a {Number} indicating the font size in pixels.
  getFontSize: ->
    @component?.getFontSize()

  # Public: Sets the font size for the editor.
  #
  # fontSize - A {Number} indicating the font size in pixels.
  setFontSize: (fontSize)->
    @component?.setFontSize(fontSize)

  setWidthInChars: (widthInChars) ->
    @component.getDOMNode().style.width = (@editor.getDefaultCharWidth() * widthInChars) + 'px'

  # Public: Sets the line height of the editor.
  #
  # Calling this method has no effect when called on a mini editor.
  #
  # lineHeight - A {Number} without a unit suffix identifying the CSS
  # `line-height`.
  setLineHeight: (lineHeight) ->
    @component.setLineHeight(lineHeight)

  # Public: Sets whether you want to show the indentation guides.
  #
  # showIndentGuide - A {Boolean} you can set to `true` if you want to see the
  #                   indentation guides.
  setShowIndentGuide: (showIndentGuide) ->
    @component.setShowIndentGuide(showIndentGuide)

  # Public: Enables/disables soft wrap on the editor.
  #
  # softWrap - A {Boolean} which, if `true`, enables soft wrap
  setSoftWrap: (softWrap) ->
    @editor.setSoftWrap(softWrap)

  # Public: Set whether invisible characters are shown.
  #
  # showInvisibles - A {Boolean} which, if `true`, show invisible characters.
  setShowInvisibles: (showInvisibles) ->
    @component.setShowInvisibles(showInvisibles)

  getText: ->
    @editor.getText()

  setText: (text) ->
    @editor.setText(text)

  insertText: (text) ->
    @editor.insertText(text)

  isInputEnabled: ->
    @component.isInputEnabled()

  setInputEnabled: (inputEnabled) ->
    @component.setInputEnabled(inputEnabled)

  requestDisplayUpdate: ->
    deprecate('Please remove from your code. ::requestDisplayUpdate no longer does anything')

  updateDisplay: ->
    deprecate('Please remove from your code. ::updateDisplay no longer does anything')

  resetDisplay: ->
    deprecate('Please remove from your code. ::resetDisplay no longer does anything')

  redraw: ->
    deprecate('Please remove from your code. ::redraw no longer does anything')

  # Public: Set the text to appear in the editor when it is empty.
  #
  # This only affects mini editors.
  #
  # placeholderText - A {String} of text to display when empty.
  setPlaceholderText: (placeholderText) ->
    if @component?
      @component.setProps({placeholderText})
    else
      @props.placeholderText = placeholderText

  lineElementForScreenRow: (screenRow) ->
    $(@component.lineNodeForScreenRow(screenRow))
