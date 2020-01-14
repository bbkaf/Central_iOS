//
//  ViewController.swift
//  Central_iOS
//
//  Created by HankTseng on 2020/1/14.
//  Copyright © 2020 HyerDesign. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    //CBCentralManagerDelegate: 管理central端
    //CBPeripheralDelegate: 與peripheral端連線

    enum SendDataError: Error {
        case CharacteristicNotFound
    }

    @IBOutlet weak var textView: UITextView!

    @IBOutlet weak var textField: UITextField!


    var centralManager: CBCentralManager!

    //已經連上線的peripheral要存在整體變數
    var connectPeripheral: CBPeripheral!

    var charDic = [String: CBCharacteristic]()


    override func viewDidLoad() {
        super.viewDidLoad()

        let queue = DispatchQueue.global()

        //將觸發 1# method
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    @IBAction func switchValueChange(_ sender: UISwitch) {
        guard let char = charDic["C001"] else { return }
        connectPeripheral.setNotifyValue(sender.isOn, for: char)
    }
    @IBAction func sendCLick(_ sender: UIButton) {
        let string = self.textField.text ?? ""
        if self.textView.text ?? "" == "" {
            self.textView.text = string
        } else {
            self.textView.text += "\n\(string)"
        }

        do {
            try sendData(string.data(using: .utf8)!, uuidString: "C001", writeType: .withoutResponse)
        } catch {
            print(error.localizedDescription)
        }
    }

    //MARK: - 是否配對 (custom method)
    func isPaired() -> Bool {
        let user = UserDefaults.standard
        if let uuidString = user.string(forKey: "KEY_PERIPHERAL_UUID") {
            guard let uuid = UUID(uuidString: uuidString) else { return false }
            let list = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if list.count > 0 {
                connectPeripheral = list.first!
                connectPeripheral.delegate = self
                return true
            }
        }
        return false
    }

    //MARK: - 1# method (delegate method)
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        //先判斷藍牙是否開啟，如果不是藍芽4.x也會回傳電源未開啟
        guard central.state == .poweredOn else {
            //iOS預設會跳警告訊息
            return
        }

        if isPaired() {
            //將觸發 3# method
            centralManager.connect(connectPeripheral, options: nil)
        } else {
            //將觸發 2# method
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    //MARK: - 2# method (delegate method)
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        print("找到藍芽裝置: \(peripheral.name ?? "errorName"), UUID: \(peripheral.identifier.uuidString)")

        guard peripheral.name != nil else { return }

        guard peripheral.name == "peripheral_macOS" else { return }


        centralManager.stopScan()
        //儲存遠端設備的UUID 重新連線時需要，避免已斷線且Peropheral端並未開啟廣告封包的狀況
        let user = UserDefaults.standard
        user.set(peripheral.identifier.uuidString, forKey: "KEY_PERIPHERAL_UUID")

        //找到的Peripheral assign 到整體變數(存在ram)
        connectPeripheral = peripheral
        connectPeripheral.delegate = self

        //將觸發 3# method
        centralManager.connect(connectPeripheral, options: nil)

    }

    //MARK: - 3# method (delegate method)
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        //斷線在連線時charDic裡面的物件部會重複
        charDic = [:]
        //將觸發 4# method，Central端去掃描所有Peripheral的service
        peripheral.discoverServices(nil)
    }

    //MARK: - 4# method (delegate method)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print(error?.localizedDescription ?? "")
            return
        }

        //掃描 peripheral所有service的，掃描到之後用discoverCharacteristics拿出service的characteristic
        for service in peripheral.services! {
            //將觸發 5# method
            connectPeripheral.discoverCharacteristics(nil, for: service)
        }
    }

    //MARK: - 5# method (delegate method)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print(error?.localizedDescription ?? "")
            return
        }
        for characteristic in service.characteristics! {
            let uuidString = characteristic.uuid.uuidString
            charDic[uuidString] = characteristic
            print("找到: \(uuidString)")
        }
    }

    //MARK: - 取得Peripheral端送過來的資料 (delegate method)
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        guard error == nil else {
            print(error?.localizedDescription ?? "")
            return
        }
        print(characteristic.uuid.uuidString)
        if characteristic.uuid.uuidString == "C001" {
            let data = characteristic.value! as NSData
            DispatchQueue.main.async {
                let string = String(data: data as Data, encoding: .utf8) ?? "error string"
                if self.textView.text ?? "" == "" {
                    self.textView.text = string
                } else {
                    self.textView.text += "\n\(string)"
                }
                print("didUpdateValueFor characteristic: " + string)
            }
        }
    }

    //MARK: - 將資料送到Peripheral端 (custom method)
    func sendData(_ data: Data, uuidString: String, writeType: CBCharacteristicWriteType) throws {
        guard let characteristic = charDic[uuidString] else {
            throw SendDataError.CharacteristicNotFound
        }

        connectPeripheral.writeValue(data,
                                     for: characteristic,
                                     type: writeType)
    }

    //MARK: - Peripheral端送過來的已讀 (delegate method)
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("寫入資料錯誤" + (error?.localizedDescription ?? ""))
            return
        }
        print("Peripheral收到訊息並傳送已讀")
    }


}

