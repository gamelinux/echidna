#!/usr/bin/ruby1.8

=begin
** Quick draft of NSMF Client layout
=end

require 'Qt4'

class Ui_MainWindow
    attr_reader :actionHelp
    attr_reader :actionAbout
    attr_reader :actionOpen
    attr_reader :actionDisconnect
    attr_reader :actionQuit
    attr_reader :actionPreferences
    attr_reader :centralWidget
    attr_reader :tabWidget
    attr_reader :tab
    attr_reader :tabWidget_2
    attr_reader :tab_6
    attr_reader :tab_5
    attr_reader :tab_2
    attr_reader :tabWidget_3
    attr_reader :tab_8
    attr_reader :tab_9
    attr_reader :tab_10
    attr_reader :tab_11
    attr_reader :tab_12
    attr_reader :tab_13
    attr_reader :tab_14
    attr_reader :tab_3
    attr_reader :tab_4
    attr_reader :menuBar
    attr_reader :menuBar_2
    attr_reader :menuHelp
    attr_reader :menuWdit
    attr_reader :statusBar

    def setupUi(mainWindow)
    if mainWindow.objectName.nil?
        mainWindow.objectName = "mainWindow"
    end
    mainWindow.resize(664, 573)
    @actionHelp = Qt::Action.new(mainWindow)
    @actionHelp.objectName = "actionHelp"
    @actionAbout = Qt::Action.new(mainWindow)
    @actionAbout.objectName = "actionAbout"
    @actionOpen = Qt::Action.new(mainWindow)
    @actionOpen.objectName = "actionOpen"
    @actionDisconnect = Qt::Action.new(mainWindow)
    @actionDisconnect.objectName = "actionDisconnect"
    @actionQuit = Qt::Action.new(mainWindow)
    @actionQuit.objectName = "actionQuit"
    @actionPreferences = Qt::Action.new(mainWindow)
    @actionPreferences.objectName = "actionPreferences"
    @centralWidget = Qt::Widget.new(mainWindow)
    @centralWidget.objectName = "centralWidget"
    @tabWidget = Qt::TabWidget.new(@centralWidget)
    @tabWidget.objectName = "tabWidget"
    @tabWidget.geometry = Qt::Rect.new(2, -1, 661, 521)
    @tab = Qt::Widget.new()
    @tab.objectName = "tab"
    @tabWidget_2 = Qt::TabWidget.new(@tab)
    @tabWidget_2.objectName = "tabWidget_2"
    @tabWidget_2.geometry = Qt::Rect.new(2, -1, 651, 491)
    @tab_6 = Qt::Widget.new()
    @tab_6.objectName = "tab_6"
    @tabWidget_2.addTab(@tab_6, Qt::Application.translate("MainWindow", "Escalated", nil, Qt::Application::UnicodeUTF8))
    @tab_5 = Qt::Widget.new()
    @tab_5.objectName = "tab_5"
    @tabWidget_2.addTab(@tab_5, Qt::Application.translate("MainWindow", "Real-time", nil, Qt::Application::UnicodeUTF8))
    @tabWidget.addTab(@tab, Qt::Application.translate("MainWindow", "Events", nil, Qt::Application::UnicodeUTF8))
    @tab_2 = Qt::Widget.new()
    @tab_2.objectName = "tab_2"
    @tabWidget_3 = Qt::TabWidget.new(@tab_2)
    @tabWidget_3.objectName = "tabWidget_3"
    @tabWidget_3.geometry = Qt::Rect.new(0, 0, 661, 481)
    @tab_8 = Qt::Widget.new()
    @tab_8.objectName = "tab_8"
    @tabWidget_3.addTab(@tab_8, Qt::Application.translate("MainWindow", "cxtracker", nil, Qt::Application::UnicodeUTF8))
    @tab_9 = Qt::Widget.new()
    @tab_9.objectName = "tab_9"
    @tabWidget_3.addTab(@tab_9, Qt::Application.translate("MainWindow", "sancp", nil, Qt::Application::UnicodeUTF8))
    @tab_10 = Qt::Widget.new()
    @tab_10.objectName = "tab_10"
    @tabWidget_3.addTab(@tab_10, Qt::Application.translate("MainWindow", "snort", nil, Qt::Application::UnicodeUTF8))
    @tab_11 = Qt::Widget.new()
    @tab_11.objectName = "tab_11"
    @tabWidget_3.addTab(@tab_11, Qt::Application.translate("MainWindow", "suricata", nil, Qt::Application::UnicodeUTF8))
    @tab_12 = Qt::Widget.new()
    @tab_12.objectName = "tab_12"
    @tabWidget_3.addTab(@tab_12, Qt::Application.translate("MainWindow", "daemonlogger", nil, Qt::Application::UnicodeUTF8))
    @tab_13 = Qt::Widget.new()
    @tab_13.objectName = "tab_13"
    @tabWidget_3.addTab(@tab_13, Qt::Application.translate("MainWindow", "ossec", nil, Qt::Application::UnicodeUTF8))
    @tab_14 = Qt::Widget.new()
    @tab_14.objectName = "tab_14"
    @tabWidget_3.addTab(@tab_14, Qt::Application.translate("MainWindow", "chat", nil, Qt::Application::UnicodeUTF8))
    @tab_3 = Qt::Widget.new()
    @tab_3.objectName = "tab_3"
    @tabWidget_3.addTab(@tab_3, Qt::Application.translate("MainWindow", "reports", nil, Qt::Application::UnicodeUTF8))
    @tabWidget.addTab(@tab_2, Qt::Application.translate("MainWindow", "Modules", nil, Qt::Application::UnicodeUTF8))
    @tab_4 = Qt::Widget.new()
    @tab_4.objectName = "tab_4"
    @tabWidget.addTab(@tab_4, Qt::Application.translate("MainWindow", "Status", nil, Qt::Application::UnicodeUTF8))
    mainWindow.centralWidget = @centralWidget
    @menuBar = Qt::MenuBar.new(mainWindow)
    @menuBar.objectName = "menuBar"
    @menuBar.geometry = Qt::Rect.new(0, 0, 664, 23)
    @menuBar_2 = Qt::Menu.new(@menuBar)
    @menuBar_2.objectName = "menuBar_2"
    @menuHelp = Qt::Menu.new(@menuBar)
    @menuHelp.objectName = "menuHelp"
    @menuWdit = Qt::Menu.new(@menuBar)
    @menuWdit.objectName = "menuWdit"
    mainWindow.setMenuBar(@menuBar)
    @statusBar = Qt::StatusBar.new(mainWindow)
    @statusBar.objectName = "statusBar"
    mainWindow.statusBar = @statusBar

    @menuBar.addAction(@menuBar_2.menuAction())
    @menuBar.addAction(@menuWdit.menuAction())
    @menuBar.addAction(@menuHelp.menuAction())
    @menuBar_2.addAction(@actionOpen)
    @menuBar_2.addAction(@actionDisconnect)
    @menuBar_2.addAction(@actionQuit)
    @menuHelp.addAction(@actionHelp)
    @menuHelp.addAction(@actionAbout)
    @menuWdit.addAction(@actionPreferences)

    retranslateUi(mainWindow)

    @tabWidget.setCurrentIndex(2)
    @tabWidget_2.setCurrentIndex(0)
    @tabWidget_3.setCurrentIndex(7)


    Qt::MetaObject.connectSlotsByName(mainWindow)
    end # setupUi

    def setup_ui(mainWindow)
        setupUi(mainWindow)
    end

    def retranslateUi(mainWindow)
    mainWindow.windowTitle = Qt::Application.translate("MainWindow", "The Network Security Monitoring Framework", nil, Qt::Application::UnicodeUTF8)
    @actionHelp.text = Qt::Application.translate("MainWindow", "Help", nil, Qt::Application::UnicodeUTF8)
    @actionAbout.text = Qt::Application.translate("MainWindow", "About", nil, Qt::Application::UnicodeUTF8)
    @actionOpen.text = Qt::Application.translate("MainWindow", "Connect", nil, Qt::Application::UnicodeUTF8)
    @actionDisconnect.text = Qt::Application.translate("MainWindow", "Disconnect", nil, Qt::Application::UnicodeUTF8)
    @actionQuit.text = Qt::Application.translate("MainWindow", "Exit", nil, Qt::Application::UnicodeUTF8)
    @actionPreferences.text = Qt::Application.translate("MainWindow", "Preferences", nil, Qt::Application::UnicodeUTF8)
    @tabWidget_2.setTabText(@tabWidget_2.indexOf(@tab_6), Qt::Application.translate("MainWindow", "Escalated", nil, Qt::Application::UnicodeUTF8))
    @tabWidget_2.setTabText(@tabWidget_2.indexOf(@tab_5), Qt::Application.translate("MainWindow", "Real-time", nil, Qt::Application::UnicodeUTF8))
    @tabWidget.setTabText(@tabWidget.indexOf(@tab), Qt::Application.translate("MainWindow", "Events", nil, Qt::Application::UnicodeUTF8))
    @tabWidget_3.setTabText(@tabWidget_3.indexOf(@tab_8), Qt::Application.translate("MainWindow", "cxtracker", nil, Qt::Application::UnicodeUTF8))
    @tabWidget_3.setTabText(@tabWidget_3.indexOf(@tab_9), Qt::Application.translate("MainWindow", "sancp", nil, Qt::Application::UnicodeUTF8))
    @tabWidget_3.setTabText(@tabWidget_3.indexOf(@tab_10), Qt::Application.translate("MainWindow", "snort", nil, Qt::Application::UnicodeUTF8))
    @tabWidget_3.setTabText(@tabWidget_3.indexOf(@tab_11), Qt::Application.translate("MainWindow", "suricata", nil, Qt::Application::UnicodeUTF8))
    @tabWidget_3.setTabText(@tabWidget_3.indexOf(@tab_12), Qt::Application.translate("MainWindow", "daemonlogger", nil, Qt::Application::UnicodeUTF8))
    @tabWidget_3.setTabText(@tabWidget_3.indexOf(@tab_13), Qt::Application.translate("MainWindow", "ossec", nil, Qt::Application::UnicodeUTF8))
    @tabWidget_3.setTabText(@tabWidget_3.indexOf(@tab_14), Qt::Application.translate("MainWindow", "chat", nil, Qt::Application::UnicodeUTF8))
    @tabWidget_3.setTabText(@tabWidget_3.indexOf(@tab_3), Qt::Application.translate("MainWindow", "reports", nil, Qt::Application::UnicodeUTF8))
    @tabWidget.setTabText(@tabWidget.indexOf(@tab_2), Qt::Application.translate("MainWindow", "Modules", nil, Qt::Application::UnicodeUTF8))
    @tabWidget.setTabText(@tabWidget.indexOf(@tab_4), Qt::Application.translate("MainWindow", "Status", nil, Qt::Application::UnicodeUTF8))
    @menuBar_2.title = Qt::Application.translate("MainWindow", "File", nil, Qt::Application::UnicodeUTF8)
    @menuHelp.title = Qt::Application.translate("MainWindow", "Help", nil, Qt::Application::UnicodeUTF8)
    @menuWdit.title = Qt::Application.translate("MainWindow", "Edit", nil, Qt::Application::UnicodeUTF8)
    end # retranslateUi

    def retranslate_ui(mainWindow)
        retranslateUi(mainWindow)
    end

end

module Ui
    class MainWindow < Ui_MainWindow
    end
end  # module Ui

if $0 == __FILE__
    a = Qt::Application.new(ARGV)
    u = Ui_MainWindow.new
    w = Qt::MainWindow.new
    u.setupUi(w)
    w.show
    a.exec
end
