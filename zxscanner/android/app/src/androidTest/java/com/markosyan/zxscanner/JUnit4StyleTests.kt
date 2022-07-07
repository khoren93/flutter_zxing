package com.markosyan.zxscanner

import androidx.test.ext.junit.rules.ActivityScenarioRule
import org.junit.*
import org.junit.runner.RunWith
import org.junit.runners.JUnit4
import tools.fastlane.screengrab.Screengrab
import tools.fastlane.screengrab.UiAutomatorScreenshotStrategy
import tools.fastlane.screengrab.cleanstatusbar.BluetoothState
import tools.fastlane.screengrab.cleanstatusbar.CleanStatusBar
import tools.fastlane.screengrab.cleanstatusbar.MobileDataType
import tools.fastlane.screengrab.locale.LocaleTestRule


@RunWith(JUnit4::class)
class JUnit4StyleTests {
    companion object {
        @JvmStatic
        @BeforeClass
        fun beforeAll() {
            Screengrab.setDefaultScreenshotStrategy(UiAutomatorScreenshotStrategy())
            CleanStatusBar()
                .setMobileNetworkDataType(MobileDataType.LTE)
                .setBluetoothState(BluetoothState.DISCONNECTED)
                .enable()
        }

        @JvmStatic
        @AfterClass
        fun afterAll() {
            CleanStatusBar.disable()
        }
    }

    @get:Rule
    var activityRule = ActivityScenarioRule(MainActivity::class.java)

    @Rule @JvmField
    val localeTestRule = LocaleTestRule()

    @Test
    fun testTakeScannerScreenshot() {
        Thread.sleep(3000)
        Screengrab.screenshot("01_scanner_screen")
        Thread.sleep(3000)
        Assert.assertTrue(true)
    }
}
