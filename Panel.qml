import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "cameronri.budget"
  ipcTarget: "cameronri.budget"
  manageIpc: false

  // Colors and theme
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color surface: Color.popups.background
  readonly property color borderCol: Color.popups.border
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // State data
  property var budgetState: Model.defaultState()
  property real income: 0
  property real savingsPercent: 20
  property var categories: Model.defaultCategories.slice()
  property var expenses: []

  // Category management UI state
  property bool managingCategories: false
  property string editingCategory: ""
  property int dragActiveIndex: -1
  property int dragTargetIndex: -1
  property real dragStartY: 0
  property real dragCurrentY: 0

  // Derived calculations
  readonly property string currentMonth: Model.currentMonthKey()
  readonly property var monthlyExpenses: Model.filterExpensesByMonth(expenses, currentMonth)
  readonly property real totalSpent: Model.totalExpenses(monthlyExpenses)
  readonly property real savingsTarget: Model.savingsAmount(income, savingsPercent)
  readonly property real remaining: Model.remainingBudget(income, savingsPercent, monthlyExpenses)
  readonly property bool isOverBudget: income > 0 && remaining < 0
  readonly property var categoryData: Model.categoryTotals(monthlyExpenses, categories)

  // Feedback message
  property string feedbackText: ""

  // Form inputs state
  property string selectedCategory: categories.length > 0 ? categories[0] : "Groceries"
  property bool showNewCategoryInput: false

  function clearFeedback() {
    feedbackText = ""
  }

  function showFeedback(msg) {
    feedbackText = msg
    feedbackTimer.restart()
  }

  Timer {
    id: feedbackTimer
    interval: 3500
    repeat: false
    onTriggered: root.clearFeedback()
  }

  // Load state from JSON
  function loadState(raw) {
    var s = Model.parseState(raw)
    budgetState = s
    income = s.income || 0
    savingsPercent = s.savingsPercent !== undefined ? s.savingsPercent : 20
    categories = (s.categories && s.categories.length > 0) ? s.categories : Model.defaultCategories.slice()
    expenses = Array.isArray(s.expenses) ? s.expenses : []
    if (categories.indexOf(selectedCategory) === -1 && categories.length > 0) {
      selectedCategory = categories[0]
    }
  }

  // Persist state to disk
  function persistState() {
    var data = {
      version: 1,
      income: root.income,
      savingsPercent: root.savingsPercent,
      categories: root.categories,
      expenses: root.expenses
    }
    budgetFile.setText(JSON.stringify(data, null, 2) + "\n")
  }

  // Category management functions
  function addCategory(name) {
    var res = Model.addCategory(categories, name)
    if (!res.ok) {
      showFeedback(res.error || "Failed to add category")
      return false
    }
    categories = res.categories
    persistState()
    showFeedback("Added category: " + name)
    return true
  }

  function renameCategory(oldName, newName) {
    var res = Model.renameCategory(categories, expenses, oldName, newName)
    if (!res.ok) {
      showFeedback(res.error || "Failed to rename category")
      return false
    }
    categories = res.categories
    expenses = res.expenses
    if (selectedCategory === oldName) selectedCategory = newName
    editingCategory = ""
    persistState()
    showFeedback("Renamed category to: " + newName)
    return true
  }

  function deleteCategory(name) {
    var res = Model.deleteCategory(categories, expenses, name)
    if (!res.ok) {
      showFeedback(res.error || "Failed to delete category")
      return false
    }
    categories = res.categories
    expenses = res.expenses
    if (selectedCategory === name) {
      selectedCategory = categories.length > 0 ? categories[0] : "Other"
    }
    editingCategory = ""
    persistState()
    showFeedback("Deleted category '" + name + "'" + (res.fallback ? " (assigned expenses to " + res.fallback + ")" : ""))
    return true
  }

  function moveCategory(fromIndex, toIndex) {
    var updated = Model.moveCategory(categories, fromIndex, toIndex)
    if (updated !== categories) {
      categories = updated
      persistState()
      return true
    }
    return false
  }

  // Submit expense
  function addExpense(amountStr, categoryStr, noteStr) {
    var amt = parseFloat(amountStr)
    if (isNaN(amt) || amt <= 0) {
      showFeedback("Please enter a valid amount greater than $0.")
      return false
    }

    var cat = String(categoryStr || selectedCategory).trim()
    if (!cat) cat = "Other"

    // Add category if new
    if (categories.indexOf(cat) === -1) {
      var newCats = categories.slice()
      newCats.push(cat)
      categories = newCats
    }

    var newExp = Model.createExpense(amt, cat, noteStr)
    if (!newExp) return false

    var expList = expenses.slice()
    expList.unshift(newExp) // Add to top
    expenses = expList
    persistState()

    showFeedback("Added " + Model.formatMoney(amt) + " to " + cat + "!")
    return true
  }

  function removeExpense(id) {
    var expList = expenses.filter(function(e) { return e.id !== id })
    expenses = expList
    persistState()
    showFeedback("Removed expense.")
  }

  function updateBudgetSettings(newIncome, newSavingsPct) {
    var inc = parseFloat(newIncome)
    var pct = parseFloat(newSavingsPct)
    if (isNaN(inc) || inc < 0) {
      showFeedback("Invalid income amount.")
      return false
    }
    if (isNaN(pct) || pct < 0 || pct > 100) {
      showFeedback("Savings percent must be between 0% and 100%.")
      return false
    }
    income = Math.round(inc * 100) / 100
    savingsPercent = Math.round(pct * 10) / 10
    persistState()
    showFeedback("Updated monthly budget settings!")
    return true
  }

  // Persistence handler
  readonly property string stateFilePath: Quickshell.env("HOME") + "/.local/state/omarchy/budget.json"

  FileView {
    id: budgetFile
    path: root.stateFilePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: root.loadState("")
  }

  Process {
    id: ensureDirProc
    command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/omarchy"]
    Component.onCompleted: running = true
  }

  // IPC Handler
  IpcHandler {
    target: "cameronri.budget"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function status(): string {
      return JSON.stringify({
        income: root.income,
        savingsPercent: root.savingsPercent,
        savingsTarget: root.savingsTarget,
        totalSpent: root.totalSpent,
        remaining: root.remaining,
        expensesCount: root.monthlyExpenses.length
      })
    }
    function add(amount: string, category: string, note: string): string {
      var ok = root.addExpense(amount, category, note)
      return ok ? "ok" : "invalid"
    }
    function setIncome(amount: string): string {
      var ok = root.updateBudgetSettings(amount, root.savingsPercent)
      return ok ? "ok" : "invalid"
    }
    function setSavings(percent: string): string {
      var ok = root.updateBudgetSettings(root.income, percent)
      return ok ? "ok" : "invalid"
    }
    function addCategory(name: string): string {
      return root.addCategory(name) ? "ok" : "invalid"
    }
    function renameCategory(oldName: string, newName: string): string {
      return root.renameCategory(oldName, newName) ? "ok" : "invalid"
    }
    function deleteCategory(name: string): string {
      return root.deleteCategory(name) ? "ok" : "invalid"
    }
    function moveCategory(fromIndex: int, toIndex: int): string {
      return root.moveCategory(fromIndex, toIndex) ? "ok" : "invalid"
    }
  }

  // Bar icon button
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "$"
    active: root.isOverBudget
    tooltipText: "Budget: " + (root.income > 0 ? Model.formatMoney(root.remaining) + " remaining" : "Not configured")
    onPressed: function(buttonCode) {
      root.toggle()
    }
  }

  // Popup Keyboard Panel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(500))
    contentHeight: panel.fittedContentHeight(scrollContent.implicitHeight + Style.space(24), Style.space(700))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: amountInput.activeFocus
        || noteInput.activeFocus
        || incomeInput.activeFocus
        || savingsInput.activeFocus
        || customCatInput.activeFocus
        || newCategoryInput.activeFocus
        || root.editingCategory !== ""
        || root.dragActiveIndex !== -1
      onCloseRequested: root.close()

      Flickable {
        id: flickArea
        anchors.fill: parent
        contentWidth: scrollContent.width
        contentHeight: scrollContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: scrollContent
          width: flickArea.width - Style.space(16)
          anchors.left: parent.left
          anchors.leftMargin: Style.space(2)
          spacing: Style.space(16)

          // -----------------------------------------------------------------
          // 1. HEADER / HERO
          // -----------------------------------------------------------------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroLeft.implicitHeight, closeBtn.implicitHeight)

            Row {
              id: heroLeft
              anchors.left: parent.left
              anchors.right: closeBtn.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(12)

              Text {
                text: "$"
                color: root.isOverBudget ? root.urgent : root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  text: "Spending & Budget"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                Text {
                  text: Model.monthLabel(root.currentMonth)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Button {
              id: closeBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "✕"
              bordered: false
              fontSize: Style.font.bodySmall
              onClicked: root.close()
            }
          }

          // Feedback banner if any
          BorderSurface {
            visible: root.feedbackText !== ""
            width: parent.width
            implicitHeight: feedbackTextLabel.implicitHeight + Style.space(14)
            height: implicitHeight
            radius: Style.cornerRadius
            color: Style.selectedFillFor(root.foreground, root.accent)

            Text {
              id: feedbackTextLabel
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              text: root.feedbackText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          // -----------------------------------------------------------------
          // 2. SUMMARY METRICS CARDS
          // -----------------------------------------------------------------
          Grid {
            width: parent.width
            columns: 2
            spacing: Style.space(8)

            // Monthly Income
            BorderSurface {
              width: (parent.width - Style.space(8)) / 2
              implicitHeight: incomeCol.implicitHeight + Style.space(18)
              height: implicitHeight
              radius: Style.cornerRadius
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
              border.width: 1
              color: Style.controlFill(false, false, root.foreground, root.accent)

              Column {
                id: incomeCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(3)

                Text {
                  text: "MONTHLY INCOME"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                Text {
                  text: Model.formatMoney(root.income)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
              }
            }

            // Savings Goal
            BorderSurface {
              width: (parent.width - Style.space(8)) / 2
              implicitHeight: savingsCol.implicitHeight + Style.space(18)
              height: implicitHeight
              radius: Style.cornerRadius
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
              border.width: 1
              color: Style.controlFill(false, false, root.foreground, root.accent)

              Column {
                id: savingsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(3)

                Text {
                  text: "SAVINGS (" + root.savingsPercent + "%)"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                Text {
                  text: Model.formatMoney(root.savingsTarget)
                  color: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
              }
            }

            // Total Spent
            BorderSurface {
              width: (parent.width - Style.space(8)) / 2
              implicitHeight: spentCol.implicitHeight + Style.space(18)
              height: implicitHeight
              radius: Style.cornerRadius
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
              border.width: 1
              color: Style.controlFill(false, false, root.foreground, root.accent)

              Column {
                id: spentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(3)

                Text {
                  text: "TOTAL SPENT"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                Text {
                  text: Model.formatMoney(root.totalSpent)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
              }
            }

            // Remaining Budget
            BorderSurface {
              width: (parent.width - Style.space(8)) / 2
              implicitHeight: remCol.implicitHeight + Style.space(18)
              height: implicitHeight
              radius: Style.cornerRadius
              border.color: root.isOverBudget ? root.urgent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
              border.width: 1
              color: root.isOverBudget
                ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.15)
                : Style.controlFill(false, false, root.foreground, root.accent)

              Column {
                id: remCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(3)

                Text {
                  text: root.isOverBudget ? "OVER BUDGET!" : "REMAINING BUDGET"
                  color: root.isOverBudget ? root.urgent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                Text {
                  text: Model.formatMoney(root.remaining)
                  color: root.isOverBudget ? root.urgent : (root.income > 0 ? root.foreground : root.dim)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
              }
            }
          }

          // Visual budget bar
          Item {
            width: parent.width
            height: Style.space(10)
            visible: root.income > 0

            Rectangle {
              id: barBackground
              anchors.fill: parent
              radius: height / 2
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
            }

            Item {
              anchors.fill: parent
              clip: true

              // Savings segment
              Rectangle {
                anchors.left: parent.left
                height: parent.height
                width: Math.min(parent.width, parent.width * (root.savingsTarget / root.income))
                color: root.accent
                opacity: 0.85
                radius: parent.height / 2
              }

              // Spent segment
              Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: Math.min(parent.width, parent.width * (root.savingsTarget / root.income))
                height: parent.height
                width: Math.min(Math.max(0, parent.width - parent.children[0].width), parent.width * (root.totalSpent / root.income))
                color: root.isOverBudget ? root.urgent : Qt.darker(root.foreground, 1.2)
                radius: parent.height / 2
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // -----------------------------------------------------------------
          // 3. QUICK ADD PURCHASE
          // -----------------------------------------------------------------
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "ADD PURCHASE"
              foreground: root.foreground
            }

            // Amount and Category row
            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: amountInput
                width: Style.space(130)
                placeholderText: "$ 0.00"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onAccepted: noteInput.forceActiveFocus()
              }

              Dropdown {
                id: categorySelect
                width: parent.width - amountInput.width - Style.space(8)
                options: root.categories.concat(["+ Custom Category..."])
                value: root.selectedCategory
                showLabel: false
                onChanged: function(newVal) {
                  if (newVal === "+ Custom Category...") {
                    root.showNewCategoryInput = true
                    Qt.callLater(function() { customCatInput.forceActiveFocus() })
                  } else {
                    root.showNewCategoryInput = false
                    root.selectedCategory = newVal
                  }
                }
              }
            }

            // Custom category input row (if selected from dropdown)
            Row {
              visible: root.showNewCategoryInput
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: customCatInput
                width: parent.width - Style.space(80)
                placeholderText: "New category name..."
              }

              Button {
                width: Style.space(72)
                text: "Use"
                bordered: true
                onClicked: {
                  if (customCatInput.text.trim()) {
                    var c = customCatInput.text.trim()
                    root.addCategory(c)
                    root.selectedCategory = c
                    root.showNewCategoryInput = false
                    customCatInput.text = ""
                  }
                }
              }
            }

            // Note and Add Button row
            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: noteInput
                width: parent.width - Style.space(100)
                placeholderText: "Description / note (optional)"
                onAccepted: addBtn.clicked()
              }

              Button {
                id: addBtn
                width: Style.space(92)
                text: "Add"
                bordered: true
                selected: true
                onClicked: {
                  var cat = root.showNewCategoryInput && customCatInput.text.trim() !== ""
                    ? customCatInput.text.trim()
                    : root.selectedCategory
                  var ok = root.addExpense(amountInput.text, cat, noteInput.text)
                  if (ok) {
                    amountInput.text = ""
                    noteInput.text = ""
                    if (root.showNewCategoryInput) {
                      root.showNewCategoryInput = false
                      customCatInput.text = ""
                    }
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // -----------------------------------------------------------------
          // 4. CATEGORIES: RUNNING TOTALS & EDIT / DELETE / ADD
          // -----------------------------------------------------------------
          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(catHeader.implicitHeight, manageCatBtn.implicitHeight)

              PanelSectionHeader {
                id: catHeader
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.managingCategories ? "MANAGE CATEGORIES (drag ⠿ to reorder)" : "CATEGORY RUNNING TOTALS"
                foreground: root.foreground
              }

              Button {
                id: manageCatBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.managingCategories ? "Done" : "Manage"
                bordered: true
                fontSize: Style.font.caption
                onClicked: {
                  root.managingCategories = !root.managingCategories
                  root.editingCategory = ""
                }
              }
            }

            // Normal View: Running Totals Breakdown
            Column {
              visible: !root.managingCategories
              width: parent.width
              spacing: Style.space(8)

              Repeater {
                model: root.categoryData

                Column {
                  required property var modelData
                  width: parent.width
                  spacing: Style.space(3)

                  Item {
                    width: parent.width
                    implicitHeight: Math.max(catText.implicitHeight, catTotalText.implicitHeight)

                    Text {
                      id: catText
                      anchors.left: parent.left
                      anchors.right: catTotalText.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.category
                      color: modelData.total > 0 ? root.foreground : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: modelData.total > 0
                      elide: Text.ElideRight
                    }

                    Text {
                      id: catTotalText
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      text: Model.formatMoney(modelData.total) + (modelData.total > 0 && root.totalSpent > 0 ? " (" + modelData.percent + "%)" : "")
                      color: modelData.total > 0 ? root.foreground : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: modelData.total > 0
                    }
                  }

                  // Progress track
                  Rectangle {
                    width: parent.width
                    height: Style.space(3)
                    radius: 2
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

                    Rectangle {
                      height: parent.height
                      width: modelData.total > 0 ? Math.max(2, parent.width * (modelData.percent / 100)) : 0
                      radius: 2
                      color: root.accent
                      visible: modelData.total > 0
                    }
                  }
                }
              }
            }

            // Management View: Add, Rename, Delete Categories
            Column {
              visible: root.managingCategories
              width: parent.width
              spacing: Style.space(8)

              // Add Category Row
              Item {
                width: parent.width
                implicitHeight: Math.max(newCategoryInput.implicitHeight, addCategoryBtn.implicitHeight)
                height: implicitHeight

                TextField {
                  id: newCategoryInput
                  anchors.left: parent.left
                  anchors.right: addCategoryBtn.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  placeholderText: "New category name..."
                  onAccepted: addCategoryBtn.clicked()
                }

                Button {
                  id: addCategoryBtn
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: "+ Add"
                  bordered: true
                  onClicked: {
                    if (newCategoryInput.text.trim()) {
                      root.addCategory(newCategoryInput.text.trim())
                      newCategoryInput.text = ""
                    }
                  }
                }
              }

              // List of categories to edit / delete
              Text {
                visible: root.categories.length === 0
                text: "No categories configured. Add one above!"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Column {
                id: categoryListCol
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: root.categories

                  Item {
                    id: slotItem
                    required property int index
                    required property string modelData
                    width: parent.width
                    height: catSurface.height
                    z: catSurface.isDragged ? 100 : 1

                    readonly property real slotHeight: height + categoryListCol.spacing
                    readonly property real shiftOffset: {
                      if (root.dragActiveIndex === -1 || root.dragActiveIndex === root.dragTargetIndex) return 0;
                      if (root.dragActiveIndex < root.dragTargetIndex) {
                        if (index > root.dragActiveIndex && index <= root.dragTargetIndex) {
                          return -slotHeight;
                        }
                      } else if (root.dragActiveIndex > root.dragTargetIndex) {
                        if (index >= root.dragTargetIndex && index < root.dragActiveIndex) {
                          return slotHeight;
                        }
                      }
                      return 0;
                    }

                    BorderSurface {
                      id: catSurface
                      readonly property bool isDragged: root.dragActiveIndex === slotItem.index
                      width: parent.width
                      implicitHeight: (root.editingCategory === slotItem.modelData ? editCardItem.height : displayCardItem.height) + Style.space(16)
                      height: implicitHeight
                      radius: Style.cornerRadius
                      border.color: isDragged ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                      border.width: isDragged ? 2 : 1
                      color: isDragged
                        ? Style.selectedFillFor(root.foreground, root.accent)
                        : Style.controlFill(false, false, root.foreground, root.accent)
                      opacity: isDragged ? 0.95 : 1.0

                      y: isDragged ? (root.dragCurrentY - root.dragStartY) : slotItem.shiftOffset

                      Behavior on y {
                        enabled: !catSurface.isDragged
                        NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                      }

                      // Display Row (When not editing this item)
                      Item {
                        id: displayCardItem
                        visible: root.editingCategory !== slotItem.modelData
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Style.space(8)
                        anchors.rightMargin: Style.space(10)
                        height: Math.max(catNameLabel.implicitHeight, actionBtns.implicitHeight, Style.space(26))

                        // Drag handle grip
                        Item {
                          id: dragHandle
                          width: Style.space(24)
                          height: parent.height
                          anchors.left: parent.left
                          anchors.verticalCenter: parent.verticalCenter

                          Grid {
                            anchors.centerIn: parent
                            columns: 2
                            spacing: Style.space(3)
                            opacity: dragHandleArea.containsMouse || catSurface.isDragged ? 1.0 : 0.45

                            Repeater {
                              model: 6
                              Rectangle {
                                width: Style.space(3)
                                height: Style.space(3)
                                radius: width / 2
                                color: dragHandleArea.containsMouse || catSurface.isDragged ? root.accent : root.foreground
                              }
                            }
                          }

                          MouseArea {
                            id: dragHandleArea
                            anchors.fill: parent
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            hoverEnabled: true
                            preventStealing: true

                            onPressed: function(mouse) {
                              root.dragActiveIndex = slotItem.index
                              root.dragTargetIndex = slotItem.index
                              var pt = dragHandleArea.mapToItem(null, mouse.x, mouse.y)
                              root.dragStartY = pt.y
                              root.dragCurrentY = pt.y
                            }

                            onPositionChanged: function(mouse) {
                              if (root.dragActiveIndex === slotItem.index) {
                                var pt = dragHandleArea.mapToItem(null, mouse.x, mouse.y)
                                root.dragCurrentY = pt.y

                                var deltaY = root.dragCurrentY - root.dragStartY
                                var slotH = slotItem.slotHeight
                                var slots = Math.round(deltaY / slotH)
                                var target = Math.max(0, Math.min(root.categories.length - 1, root.dragActiveIndex + slots))
                                root.dragTargetIndex = target
                              }
                            }

                            onReleased: function(mouse) {
                              if (root.dragActiveIndex === slotItem.index) {
                                var from = root.dragActiveIndex
                                var to = root.dragTargetIndex
                                root.dragActiveIndex = -1
                                root.dragTargetIndex = -1
                                if (to >= 0 && to !== from) {
                                  root.moveCategory(from, to)
                                }
                              }
                            }

                            onCanceled: {
                              root.dragActiveIndex = -1
                              root.dragTargetIndex = -1
                            }
                          }
                        }

                        Text {
                          id: catNameLabel
                          anchors.left: dragHandle.right
                          anchors.right: actionBtns.left
                          anchors.leftMargin: Style.space(6)
                          anchors.rightMargin: Style.space(8)
                          anchors.verticalCenter: parent.verticalCenter
                          text: slotItem.modelData
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.bodySmall
                          font.bold: true
                          elide: Text.ElideRight
                        }

                        Row {
                          id: actionBtns
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: Style.space(6)

                          Button {
                            text: "Rename"
                            bordered: true
                            fontSize: Style.font.caption
                            verticalPadding: Style.space(4)
                            horizontalPadding: Style.space(8)
                            onClicked: {
                              renameInput.text = slotItem.modelData
                              root.editingCategory = slotItem.modelData
                            }
                          }

                          Button {
                            text: "Delete"
                            bordered: true
                            fontSize: Style.font.caption
                            verticalPadding: Style.space(4)
                            horizontalPadding: Style.space(8)
                            onClicked: root.deleteCategory(slotItem.modelData)
                          }
                        }
                      }

                      // Edit Row (When editing this item)
                      Item {
                        id: editCardItem
                        visible: root.editingCategory === slotItem.modelData
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Style.space(10)
                        anchors.rightMargin: Style.space(10)
                        height: Math.max(renameInput.implicitHeight, renameActions.implicitHeight, Style.space(30))

                        TextField {
                          id: renameInput
                          anchors.left: parent.left
                          anchors.right: renameActions.left
                          anchors.rightMargin: Style.space(8)
                          anchors.verticalCenter: parent.verticalCenter
                          text: slotItem.modelData
                          onAccepted: saveRenameBtn.clicked()
                        }

                        Row {
                          id: renameActions
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: Style.space(6)

                          Button {
                            id: saveRenameBtn
                            text: "Save"
                            bordered: true
                            fontSize: Style.font.caption
                            verticalPadding: Style.space(4)
                            horizontalPadding: Style.space(8)
                            onClicked: {
                              if (renameInput.text.trim()) {
                                root.renameCategory(slotItem.modelData, renameInput.text.trim())
                              }
                            }
                          }

                          Button {
                            text: "Cancel"
                            bordered: true
                            fontSize: Style.font.caption
                            verticalPadding: Style.space(4)
                            horizontalPadding: Style.space(8)
                            onClicked: root.editingCategory = ""
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // -----------------------------------------------------------------
          // 5. MONTHLY BUDGET & SAVINGS SETTINGS
          // -----------------------------------------------------------------
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "BUDGET CONFIGURATION"
              foreground: root.foreground
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Column {
                id: incomeCol
                spacing: Style.space(2)
                Text {
                  id: incomeLabel
                  text: "Monthly Income ($)"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                TextField {
                  id: incomeInput
                  width: Style.space(130)
                  text: root.income > 0 ? String(root.income) : ""
                  placeholderText: "e.g. 4000.00"
                  inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
              }

              Column {
                id: savingsCol
                spacing: Style.space(2)
                Text {
                  id: savingsLabel
                  text: "Save Target (%)"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                TextField {
                  id: savingsInput
                  width: Style.space(90)
                  text: String(root.savingsPercent)
                  placeholderText: "20"
                  inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
              }

              Column {
                spacing: Style.space(2)

                Item {
                  width: 1
                  height: incomeLabel.implicitHeight
                }

                Button {
                  id: saveBudgetBtn
                  height: incomeInput.height
                  text: "Save Budget"
                  bordered: true
                  onClicked: {
                    root.updateBudgetSettings(incomeInput.text, savingsInput.text)
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // -----------------------------------------------------------------
          // 6. RECENT TRANSACTIONS
          // -----------------------------------------------------------------
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "RECENT TRANSACTIONS (" + root.monthlyExpenses.length + ")"
              foreground: root.foreground
            }

            Text {
              visible: root.monthlyExpenses.length === 0
              text: "No expenses recorded this month yet."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.monthlyExpenses.slice(0, 10)

                BorderSurface {
                  required property var modelData
                  width: parent.width
                  radius: Style.cornerRadius
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                  border.width: 1
                  color: Style.controlFill(false, false, root.foreground, root.accent)
                  implicitHeight: txRowItem.height + Style.space(16)
                  height: implicitHeight

                  Item {
                    id: txRowItem
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    height: Math.max(txInfoCol.implicitHeight, txAmountCol.implicitHeight, txDeleteBtn.implicitHeight)

                    Column {
                      id: txInfoCol
                      anchors.left: parent.left
                      anchors.right: txAmountCol.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)

                      Row {
                        spacing: Style.space(6)
                        Text {
                          text: modelData.category
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                        Text {
                          text: Model.formatShortDate(modelData.date)
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                      }

                      Text {
                        visible: modelData.note !== ""
                        text: modelData.note || ""
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                        width: parent.width
                      }
                    }

                    Column {
                      id: txAmountCol
                      anchors.right: txDeleteBtn.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        text: Model.formatMoney(modelData.amount)
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                      }
                    }

                    Button {
                      id: txDeleteBtn
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      text: "✕"
                      bordered: false
                      fontSize: Style.font.caption
                      tooltipText: "Delete transaction"
                      onClicked: root.removeExpense(modelData.id)
                    }
                  }
                }
              }
            }
          }

          // Bottom breathing room
          Item {
            width: parent.width
            height: Style.space(8)
          }

        }
      }
    }
  }
}
