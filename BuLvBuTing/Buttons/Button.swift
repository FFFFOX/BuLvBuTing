//
//  File.swift
//  BuLvBuTing
//
//  Created by Maximus Pro on 2020/10/14.
//

import UIKit

class Button: UIButton {
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel?.font = UIFont(name: "Avenir", size: 12)
    }
}
