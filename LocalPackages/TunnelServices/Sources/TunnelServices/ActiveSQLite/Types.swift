//
//  Types.swift
//  ActiveSQLite
//
//  Created by kai zhou on 2018/8/13.
//  Copyright © 2018 wumingapie@gmail.com. All rights reserved.
//

import Foundation
import SQLite

func isSupportTypes(_ value:Any)->Bool{
    let mir = Mirror(reflecting:value)
    
    switch mir.subjectType {
        
    case _ as String.Type,_ as String?.Type,
//         _ as Int64.Type,_ as Int64?.Type,
//         _ as Int.Type,_ as Int?.Type,
//         _ as Double.Type,_ as Double?.Type,
//         _ as Date.Type,_ as Date?.Type,
         _ as NSNumber.Type,_ as NSNumber?.Type,
         _ as NSDate.Type,_ as NSDate?.Type:
        return true
        
    default:
        return false
    }
}

extension NSNumber : SQLite.Value {
    public static var declaredDatatype: String {
        return Int64.declaredDatatype
    }
    
    public static func fromDatatypeValue(_ datatypeValue: Int64) -> NSNumber {
        return NSNumber(value:datatypeValue)
    }
    public var datatypeValue: Int64 {
        return Int64(truncating: self)
    }
    
}

//Date -- NSDate -> Int64. Date -> String
extension NSDate: SQLite.Value {
    public static var declaredDatatype: String {
        return Int64.declaredDatatype
    }
    public static func fromDatatypeValue(_ intValue: Int64) -> NSDate {
        return NSDate(timeIntervalSince1970: TimeInterval(intValue))
    }
    public var datatypeValue: Int64 {
        return  Int64(timeIntervalSince1970)
    }
}

extension Setter{
    static func generate(key:String,type:Any,value:Any?) -> Setter? {
        
        let mir = Mirror(reflecting:type)
        
        switch mir.subjectType {
            
        case _ as String.Type:
            return (SQLExpression<String>(key) <- value as! String)
            
        case _ as String?.Type:
            if let v = value as? String {
                return (SQLExpression<String?>(key) <- v)
            }else{
                return (SQLExpression<String?>(key) <- nil)
            }
        
//        case _ as Int64.Type:
//            return (SQLExpression<Int64>(key) <- value as! Int64)
//
//        case _ as Int64?.Type:
//            if let v = value as? Int64 {
//                return (SQLExpression<Int64?>(key) <- v)
//            }else{
//                return (SQLExpression<Int64?>(key) <- nil)
//            }
//
//        case _ as Int.Type:
//            return (SQLExpression<Int>(key) <- value as! Int)
//
//        case _ as Int?.Type:
//            if let v = value as? Int {
//                return (SQLExpression<Int?>(key) <- v)
//            }else{
//                return (SQLExpression<Int?>(key) <- nil)
//            }
//
//        case _ as Double.Type:
//            return (SQLExpression<Double>(key) <- value as! Double)
//
//        case _ as Double?.Type:
//            if let v = value as? Double {
//                return (SQLExpression<Double?>(key) <- v)
//            }else{
//                return (SQLExpression<Double?>(key) <- nil)
//            }

        case _ as Date.Type:
            return (SQLExpression<Date>(key) <- value as! Date)
            
        case _ as Date?.Type:
            if let v = value as? Date {
                return (SQLExpression<Date?>(key) <- v)
            }else{
                return (SQLExpression<Date?>(key) <- nil)
            }
            
        case _ as NSNumber.Type:
            return (SQLExpression<NSNumber>(key) <- value as! NSNumber)
            
        case _ as NSNumber?.Type:
            if let v = value as? NSNumber {
                return (SQLExpression<NSNumber?>(key) <- v)
            }else{
                return (SQLExpression<NSNumber?>(key) <- nil)
            }
            
        case _ as NSDate.Type:
            return (SQLExpression<NSDate>(key) <- value as! NSDate)
        case _ as NSDate?.Type:
            
            if let v = value as? NSDate {
                return (SQLExpression<NSDate?>(key) <- v)
            }else{
                return (SQLExpression<NSDate?>(key) <- nil)
            }
            
        default:
            return nil
        }
    }
}

extension SQLExpression{
    static func generate(key:String,type:Any,value:Any?) -> SQLExpression<Bool?>?{
        let mir = Mirror(reflecting:type)
        
        switch mir.subjectType {
            
        case _ as String.Type:
            return (SQLExpression<Bool?>(SQLExpression<String>(key) == value as! String))
        case _ as String?.Type:
            return (SQLExpression<String?>(key) == value as! String?)
        
//        case _ as Int64.Type:
//            return (SQLExpression<Bool?>(SQLExpression<Int64>(key) == value as! Int64))
//        case _ as Int64?.Type:
//            return (SQLExpression<Int64?>(key) == value as! Int64?)
//            
//        case _ as Int.Type:
//            return (SQLExpression<Bool?>(SQLExpression<Int>(key) == value as! Int))
//        case _ as Int?.Type:
//            return (SQLExpression<Int?>(key) == value as! Int?)
//            
//        case _ as Double.Type:
//            return (SQLExpression<Bool?>(SQLExpression<Double>(key) == value as! Double))
//        case _ as Double?.Type:
//            return (SQLExpression<Double?>(key) == value as! Double?)
//            
//        case _ as Date.Type:
//            return (SQLExpression<Bool?>(SQLExpression<Date>(key) == value as! Date))
//        case _ as Date?.Type:
//            return (SQLExpression<Date?>(key) == value as! Date?)
            
            
        case _ as NSNumber.Type:
            return (SQLExpression<Bool?>(SQLExpression<NSNumber>(key) == value as! NSNumber))
        case _ as NSNumber?.Type:
            return (SQLExpression<NSNumber?>(key) == value as? NSNumber)
            
        case _ as NSDate.Type:
            return (SQLExpression<Bool?>(SQLExpression<NSDate>(key) == value as! NSDate))
        case _ as NSDate?.Type:
            return (SQLExpression<NSDate?>(key) == value as! NSDate?)
            
        default:
            return nil
        }
    }
}
