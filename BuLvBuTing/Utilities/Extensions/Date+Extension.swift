//
//  Date+Extension.swift
//  BuLvBuTing
//
//  Created by Maximus Pro on 2020/10/14.
//

import UIKit

extension Date {
    func toMillis() -> Int64! {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}
