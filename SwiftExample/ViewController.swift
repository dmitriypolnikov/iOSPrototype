//
//  ViewController.swift
//  SwiftExample
//
//  Created by Belal Khan on 18/11/17.
//  Copyright © 2017 Belal Khan. All rights reserved.
//

import UIKit
import SQLite3

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    

    var db: OpaquePointer?
    var heroList = [Hero]()
    
    @IBOutlet weak var tableViewHeroes: UITableView!
    
    var updateTimer: Timer?
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    var timer : Timer?
    var backgroundTask1 = BackgroundTask()
    
    func getHTMLContent() -> String {
        
        let myURLString = "https://www.websiteplanet.com/test.php"
        
        var myHTMLString: String = ""
        
        if let myURL = NSURL(string: myURLString) {
            do {
                myHTMLString = try NSString(contentsOf: myURL as URL, encoding: String.Encoding.utf8.rawValue) as String
                print("html \(myHTMLString)")
            } catch {
                print(error)
            }
        }
        
        return myHTMLString
    }
    
   
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return heroList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "cell")
        let hero: Hero
        hero = heroList[indexPath.row]
        cell.textLabel?.text = String.init(format: "%@ : %@", hero.name!, hero.powerRanking!)
        return cell
    }
    
    
    func readValues(){
        heroList.removeAll()

        let queryString = "SELECT * FROM Heroes"
        
        var stmt:OpaquePointer?
        
        if sqlite3_prepare(db, queryString, -1, &stmt, nil) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing insert: \(errmsg)")
            return
        }
        
        while(sqlite3_step(stmt) == SQLITE_ROW){
            let id = sqlite3_column_int(stmt, 0)
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let powerrank = String(cString: sqlite3_column_text(stmt, 2))
            
            heroList.append(Hero(id: Int(id), name: String(describing: name), powerRanking: String(describing:powerrank)))
        }
        
        self.tableViewHeroes.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appdelegate : AppDelegate = UIApplication.shared.delegate as! AppDelegate
        appdelegate.m_view? = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(reinstateBackgroundTask), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        let fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("HeroesDatabase.sqlite")
        
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("error opening database")
        }
        
        if sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS Heroes (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, powerrank TEXT)", nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error creating table: \(errmsg)")
        }
        
        registerBackgroundTask()
        readValues()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func reinstateBackgroundTask() {
        
        readValues()
        
        self.stopBackgroundTask()
        
        updateTimer = Timer.scheduledTimer(timeInterval: 300.0, target: self,
                                           selector: #selector(sendStatus), userInfo: nil, repeats: true)
        
        if updateTimer != nil && (backgroundTask == UIBackgroundTaskInvalid) {
            registerBackgroundTask()
        }
    }
    
    func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            
            self?.updateTimer?.invalidate()
            
            self?.startBackgroundTask()
        }
        assert(backgroundTask != UIBackgroundTaskInvalid)
    }
    
    func endBackgroundTask() {
        print("Background task ended.")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = UIBackgroundTaskInvalid
    }
    
    @objc func sendStatus() {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd hh:mm"
        let currentDate = dateFormatter.string(from: Date())
        
        let content = getHTMLContent()
        
        var stmt: OpaquePointer?
        
        let queryString = "INSERT INTO Heroes (name, powerrank) VALUES (?,?)"
        
        if sqlite3_prepare(db, queryString, -1, &stmt, nil) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing insert: \(errmsg)")
            return
        }
        
        if sqlite3_bind_text(stmt, 1, currentDate, -1, nil) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure binding name: \(errmsg)")
            return
        }
        
        if sqlite3_bind_text(stmt, 2, content, -1, nil) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure binding name: \(errmsg)")
            return
        }
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure inserting hero: \(errmsg)")
            return
        }
        
        switch UIApplication.shared.applicationState {
            case .active:
                readValues()
            case .background:
                print("App is backgrounded.")
                print("Background time remaining = \(UIApplication.shared.backgroundTimeRemaining) seconds")
            case .inactive:
                break
        }
    }
    
    func startBackgroundTask() {
        backgroundTask1.startBackgroundTask()
        timer = Timer.scheduledTimer(timeInterval: 300.0, target: self, selector: #selector(ViewController.timerAction), userInfo: nil, repeats: true)
    }
    
    func stopBackgroundTask() {
        if timer != nil {
            timer?.invalidate()
            backgroundTask1.stopBackgroundTask()
        }
    }
    
    @objc func timerAction() {
        self.sendStatus()
    }
}

