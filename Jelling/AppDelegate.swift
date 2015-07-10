//
// Authors: Nathaniel McCallum <npmccallum@redhat.com>
//
// Copyright (C) 2015  Nathaniel McCallum, Red Hat
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Cocoa
import Carbon
import CoreBluetooth

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CBPeripheralManagerDelegate {
    private let VERSION = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"]! as! String
    private let STRING_VERSION = NSLocalizedString("Version %@", comment: "")
    private let STRING_ABOUT = NSLocalizedString("About Jelling", comment: "")
    private let STRING_QUIT = NSLocalizedString("Quit", comment: "")
    private let MAXLEN = 32
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var version: NSTextField!
    @IBOutlet weak var project: NSButton!
    @IBOutlet weak var license: NSButton!

    let itm = NSStatusBar.systemStatusBar().statusItemWithLength(NSSquareStatusItemLength)
    
    var man: CBPeripheralManager!

    let svc = CBMutableService(
        type: CBUUID(string: "B670003C-0079-465C-9BA7-6C0539CCD67F"),
        primary: true
    )

    let chr = CBMutableCharacteristic(
        type: CBUUID(string: "F4186B06-D796-4327-AF39-AC22C50BDCA8"),
        properties: .Write,
        value: nil,
        permissions: .WriteEncryptionRequired
    )

    private func char2code(c: UInt8) -> CGKeyCode {
        switch (c) {
        case 48: return CGKeyCode(kVK_ANSI_0); // ASCII '0'
        case 49: return CGKeyCode(kVK_ANSI_1); // ASCII '1'
        case 50: return CGKeyCode(kVK_ANSI_2); // ASCII '2'
        case 51: return CGKeyCode(kVK_ANSI_3); // ASCII '3'
        case 52: return CGKeyCode(kVK_ANSI_4); // ASCII '4'
        case 53: return CGKeyCode(kVK_ANSI_5); // ASCII '5'
        case 54: return CGKeyCode(kVK_ANSI_6); // ASCII '6'
        case 55: return CGKeyCode(kVK_ANSI_7); // ASCII '7'
        case 56: return CGKeyCode(kVK_ANSI_8); // ASCII '8'
        case 57: return CGKeyCode(kVK_ANSI_9); // ASCII '9'
        default: return CGKeyCode(UINT16_MAX);
        }
    }
    
    private func press(code: CGKeyCode, down: Bool) -> Bool {
        if let e = CGEventCreateKeyboardEvent(nil, code, down) {
            CGEventPost(.CGAnnotatedSessionEventTap, e);
            return down ? press(code, down: false) : true;
        }
        
        return false
    }

    func about(sender: AnyObject) {
        window.makeKeyAndOrderFront(sender)
        NSApp.activateIgnoringOtherApps(true)
    }

    func quit(sender: AnyObject) {
        NSApplication.sharedApplication().terminate(sender)
    }

    @IBAction func onURLClick(sender: NSButton) {
        NSWorkspace.sharedWorkspace().openURL(NSURL(string: sender.title)!)
    }
    
    private func linkify(button: NSButton) {
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                NSLinkAttributeName: button.title,
                NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue,
                NSForegroundColorAttributeName: NSColor.blueColor()
            ]
        )
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        version.stringValue = String(format: STRING_VERSION, VERSION)
        window.center()
        linkify(project)
        linkify(license)

        itm.menu = NSMenu()
        itm.menu?.addItemWithTitle(STRING_ABOUT, action: "about:", keyEquivalent: "")
        itm.menu?.addItemWithTitle(STRING_QUIT, action: "quit:", keyEquivalent: "")
        itm.button!.image = NSImage(named: "jelling")
        itm.button!.image?.template = true

        svc.characteristics = [ chr ]
        man = CBPeripheralManager(delegate: self, queue: nil)
        man.addService(svc)
    }

    func applicationWillTerminate(notification: NSNotification) {
        NSStatusBar.systemStatusBar().removeStatusItem(itm)
    }

    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .PoweredOn: peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [svc.UUID!]])
        default: peripheral.stopAdvertising()
        }
    }

    func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
        var input = Array<CGKeyCode>()

        for req in requests {
            if req.characteristic.UUID != chr.UUID {
                peripheral.respondToRequest(requests[0], withResult: .AttributeNotFound)
                return
            }

            if req.value == nil || req.value!.length == 0 {
                peripheral.respondToRequest(requests[0], withResult: .InvalidAttributeValueLength)
                return
            }

            let end = req.offset + req.value!.length
            if end > MAXLEN {
                peripheral.respondToRequest(requests[0], withResult: .InvalidOffset)
                return
            }

            while input.count < end {
                input.append(CGKeyCode(UINT16_MAX))
            }

            let tmp = UnsafePointer<UInt8>(req.value!.bytes)
            for i in 0..<req.value!.length {
                input[req.offset + i] = char2code(tmp[i])
            }
        }
        
        if input.count < 1 {
            peripheral.respondToRequest(requests[0], withResult: .InvalidAttributeValueLength)
            return
        }

        for c in input {
            if c == CGKeyCode(UINT16_MAX) {
                peripheral.respondToRequest(requests[0], withResult: .InvalidPdu)
                return
            }
        }

        for c in input {
            if !press(c, down: true) {
                peripheral.respondToRequest(requests[0], withResult: .InvalidPdu)
                return
            }
        }

        press(CGKeyCode(kVK_Return), down: true);
        peripheral.respondToRequest(requests[0], withResult: .Success)
    }
}

