//
//  TouchVisualizer.swift
//  TouchVisualizer
//

import UIKit
import AVFoundation

final public class Visualizer:NSObject {
    
    // MARK: - Public Variables
    static public let sharedInstance = Visualizer()
    fileprivate var enabled = false
    fileprivate var config: Configuration!
    fileprivate var touchViews = [TouchView]()
    fileprivate var previousLog = ""
    fileprivate var previousRecLog = ""
    fileprivate var recLogs = ""
    fileprivate var countTouchTag = 1
    fileprivate var player: AVPlayer?
    fileprivate enum RecordingType {
        case STOP
        case RECORDING
        case PAUSE
    }
    fileprivate var recording:RecordingType = .STOP
    fileprivate var startedSet:Set<Int> = []
    fileprivate var endedSet:Set<Int> = []
    
    // MARK: - Object life cycle
    private override init() {
      super.init()
        NotificationCenter
            .default
            .addObserver(self, selector: #selector(Visualizer.orientationDidChangeNotification(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        
        NotificationCenter
            .default
            .addObserver(self, selector: #selector(Visualizer.applicationDidBecomeActiveNotification(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        UIDevice
            .current
            .beginGeneratingDeviceOrientationNotifications()
        
        warnIfSimulator()
    }
    
    deinit {
        NotificationCenter
            .default
            .removeObserver(self)
    }
    
    // MARK: - Helper Functions
    @objc internal func applicationDidBecomeActiveNotification(_ notification: Notification) {
        print("UIApplication.shared.keyWindow? = \(UIApplication.shared.keyWindow?.classForCoder)")
        UIApplication.shared.keyWindow?.swizzle()
    }
    
    @objc internal func orientationDidChangeNotification(_ notification: Notification) {
        let instance = Visualizer.sharedInstance
        for touch in instance.touchViews {
            touch.removeFromSuperview()
        }
    }
    
    public func removeAllTouchViews() {
        for view in self.touchViews {
            view.removeFromSuperview()
        }
    }
}

extension Visualizer {
    public class func isEnabled() -> Bool {
        return sharedInstance.enabled
    }
    
    // MARK: - Start and Stop functions
    
    public class func start(_ config: Configuration = Configuration()) {
		
		if config.showsLog {
			print("Visualizer start...")
		}
        let instance = sharedInstance
        instance.enabled = true
        instance.config = config
        
        if let window = UIApplication.shared.keyWindow {
            for subview in window.subviews {
                if let subview = subview as? TouchView {
                    subview.removeFromSuperview()
                }
            }
        }
		if config.showsLog {
			print("started !")
		}
    }
    
    public class func recStart(config: Configuration = Configuration(), player: AVPlayer?) {
        let instance = sharedInstance
        instance.countTouchTag = 1
        instance.recording = .RECORDING
        instance.recLogs = ""
        instance.player = player
        instance.startedSet = []
        instance.endedSet = []
        self.start( config )
    }
    
    public class func stop() {
        let instance = sharedInstance
        instance.enabled = false
        
        for touch in instance.touchViews {
            touch.removeFromSuperview()
        }
    }
    
    public class func recStop() -> String? {
        let instance = sharedInstance
        if instance.recording == .STOP { return nil }
        instance.recording = .STOP
        instance.player = nil
        self.stop()
        return instance.recLogs
    }
    
    public class func recPause(){
        let instance = sharedInstance
        if instance.recording != .RECORDING { return }
        instance.recording = .PAUSE
    }
    public class func recResume(){
        let instance = sharedInstance
        if instance.recording != .PAUSE { return }
        instance.recording = .RECORDING
    }
    
    
    public class func getTouches() -> [UITouch] {
        let instance = sharedInstance
        var touches: [UITouch] = []
        for view in instance.touchViews {
            guard let touch = view.touch else { continue }
            touches.append(touch)
        }
        return touches
    }
    
    // MARK: - Dequeue and locating TouchViews and handling events
    private func dequeueTouchView() -> TouchView {
        var touchView: TouchView?
        for view in touchViews {
            if view.superview == nil {
                touchView = view
                break
            }
        }
        
        if touchView == nil {
            touchView = TouchView()
            touchViews.append(touchView!)
        }
        
        return touchView!
    }
    
    private func findTouchView(_ touch: UITouch) -> TouchView? {
        for view in touchViews {
            if touch == view.touch {
                return view
            }
        }
        
        return nil
    }
    
    private func findTouchView(tag: Int) -> TouchView? {
        for view in touchViews {
            if tag == view.tag {
                return view
            }
        }
        
        return nil
    }
    
    open func handleEvent(_ event: UIEvent) {
        if event.type != .touches {
            return
        }
        
        if !Visualizer.sharedInstance.enabled {
            return
        }

        var topWindow = UIApplication.shared.keyWindow!
        for window in UIApplication.shared.windows {
            if window.isHidden == false && window.windowLevel > topWindow.windowLevel {
                topWindow = window
            }
        }
        
        for touch in event.allTouches! {
            let phase = touch.phase
            switch phase {
            case .began:
                let view = dequeueTouchView()
                view.config = Visualizer.sharedInstance.config
                view.touch = touch
                view.beginTouch()
                view.center = touch.location(in: topWindow)
                view.tag = countTouchTag
                countTouchTag += 1
                topWindow.addSubview(view)
                if recording == .RECORDING {
                    if let time = player?.currentTime() {
                        recLog(touch, tagID: view.tag, time: CMTimeGetSeconds(time))
                    }
                }
                log(touch)
            case .moved:
                if let view = findTouchView(touch) {
                    view.center = touch.location(in: topWindow)
                    
                    if recording == .RECORDING {
                        if let time = player?.currentTime() {
                            recLog(touch, tagID: view.tag, time: CMTimeGetSeconds(time))
                        }
                    }
                }
                
                log(touch)
            case .stationary:
                log(touch)
            case .ended, .cancelled:
                if let view = findTouchView(touch) {
                    UIView.animate(withDuration: 0.2, delay: 0.0, options: .allowUserInteraction, animations: { () -> Void  in
                        view.alpha = 0.0
                        view.endTouch()
                    }, completion: { [unowned self] (finished) -> Void in
                        view.removeFromSuperview()
                        self.log(touch)
                    })
                    
                    if recording == .RECORDING {
                        if let time = player?.currentTime() {
                            recLog(touch, tagID: view.tag, time: CMTimeGetSeconds(time))
                        }
                    }
                }
                
                log(touch)
            case .regionEntered: break
            case .regionMoved: break
            case .regionExited: break
            }
        }
    }
    
    public func playEvent(eventLogs: String) {
        if eventLogs == "" { return }
        
        var topWindow = UIApplication.shared.keyWindow!
        for window in UIApplication.shared.windows {
            if window.isHidden == false && window.windowLevel > topWindow.windowLevel {
                topWindow = window
            }
        }
        
        let logParams:[String] = eventLogs.components(separatedBy: ",")
        
        for i in 0 ..< logParams.count / 4 {
            
            let tagID = Int(logParams[i*4 + 0])!
            let phase = logParams[i*4 + 1]
            let center = CGPoint(x: Double(logParams[i*4 + 2])!, y: Double(logParams[i*4 + 3])!)
            switch phase {
            case "B":
                let view = dequeueTouchView()
                view.config = Visualizer.sharedInstance.config
                //view.touch = touch
                view.beginTouch()
                view.center = center
                view.tag = tagID
                topWindow.addSubview(view)
            case "M":
                if let view = findTouchView(tag: tagID) {
                    view.center = center
                }
            case "S": break
            case "E", "C":
                if let view = findTouchView(tag: tagID) {
                    UIView.animate(withDuration: 0.2, delay: 0.0, options: .allowUserInteraction, animations: { () -> Void  in
                        view.alpha = 0.0
                        view.endTouch()
                    }, completion: { (finished) -> Void in
                        view.removeFromSuperview()
                    })
                }
            default: break
            }
        }
    }
}

extension Visualizer {
    public func warnIfSimulator() {
        #if targetEnvironment(simulator)
            print("[TouchVisualizer] Warning: TouchRadius doesn't work on the simulator because it is not possible to read touch radius on it.", terminator: "")
        #endif
    }
    
    // MARK: - Logging
    public func log(_ touch: UITouch) {
        if !config.showsLog {
            return
        }
        
        var ti = 0
        var viewLogs = [[String:String]]()
        for view in touchViews {
            var index = ""
            
            index = "\(ti)"
            ti += 1
            
            var phase: String!
            switch touch.phase {
            case .began: phase = "B"
            case .moved: phase = "M"
            case .stationary: phase = "S"
            case .ended: phase = "E"
            case .cancelled: phase = "C"
            case .regionEntered: break
            case .regionMoved: break
            case .regionExited: break
            }
            
            let x = String(format: "%.02f", view.center.x)
            let y = String(format: "%.02f", view.center.y)
            let center = "(\(x), \(y))"
            let radius = String(format: "%.02f", touch.majorRadius)
            viewLogs.append(["index": index, "center": center, "phase": phase, "radius": radius])
        }
        
        var log = ""
        
        for viewLog in viewLogs {
            
            if (viewLog["index"]!).count == 0 {
                continue
            }
            
            let index = viewLog["index"]!
            let center = viewLog["center"]!
            let phase = viewLog["phase"]!
            let radius = viewLog["radius"]!
            log += "Touch: [\(index)]<\(phase)> c:\(center) r:\(radius)\t\n"
        }
        
        if log == previousLog {
            return
        }
        
        previousLog = log
        print(log, terminator: "")
    }
}

extension Visualizer {
    
    // MARK: - Logging
    public func recLog(_ touch: UITouch, tagID: Int, time: Float64) {
        var viewLogs = [[String:String]]()
        for view in touchViews {
            if endedSet.contains(view.tag){ continue }
            var phase: String!
            switch touch.phase {
            case .began:
                if startedSet.contains(view.tag){ continue }
                phase = "B"
                startedSet.insert(view.tag)
            case .moved: phase = "M"
            case .stationary: phase = "S"
            case .ended:
                phase = "E"
                endedSet.insert(view.tag)
            case .cancelled: phase = "C"
            case .regionEntered: break
            case .regionMoved: break
            case .regionExited: break
            }
            
            let tagID = "\(view.tag)"
            let x = String(format: "%.02f", view.center.x)
            let y = String(format: "%.02f", view.center.y)
            let center = "\(x),\(y)"
            let sec = "\(time)"
            viewLogs.append(["tagID": tagID, "center": center, "phase": phase, "time": sec])
        }
        
        var log = ""
        
        for viewLog in viewLogs {
            
            if (viewLog["tagID"]!).count == 0 {
                continue
            }
            
            let tagID = viewLog["tagID"]!
            let center = viewLog["center"]!
            let phase = viewLog["phase"]!
            let time = viewLog["time"]!
            log += "[\(time);\(tagID),\(phase),\(center)]"
        }
        
        if log == previousRecLog {
            return
        }
        
        previousRecLog = log
        //print(log, terminator: "")
        recLogs += log
    }
}
