//
//  CFNotification+PasteboardListener.swift
//  ClipKit
//
//  Created by Riley Testut on 6/13/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreFoundation

public extension CFNotificationName
{
    static let didChangePasteboard: CFNotificationName = CFNotificationName("com.rileytestut.Clip.DidChangePasteboard" as CFString)
    
    static let ignoreNextPasteboardChange: CFNotificationName = CFNotificationName("com.rileytestut.Clip.IgnoreNextPasteboardChange" as CFString)
}
