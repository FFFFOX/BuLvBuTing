//
//  BtnPlein.swift
//  BuLvBuTing
//
//  Created by Maximus Pro on 2020/10/14.
//

import UIKit

class BtnPlein: Button {
    override func awakeFromNib() {
        super.awakeFromNib()
        
    }
    
    var myValue: Int
    
    ///Constructor: - init
    override init(frame: CGRect) {
        // set myValue before super.init is called
        self.myValue = 0
        
        super.init(frame: frame)
        layer.borderWidth = 6/UIScreen.main.nativeScale
        layer.backgroundColor = UIColor(red:0.24, green:0.51, blue:1.00, alpha:1.0).cgColor
        setTitleColor( .white, for: .normal)
        
        layer.borderColor = UIColor(red:0.24, green:0.51, blue:1.00, alpha:1.0).cgColor
        layer.cornerRadius = 5
        
        switch UIScreen.main.nativeBounds.height {
        case 1136:
            titleLabel?.font = UIFont(name: "Avenir", size: 14)
        default:
            titleLabel?.font = UIFont(name: "Avenir", size: 20)
        }
        layer.shadowOffset = CGSize(width: 1, height: 5)
        layer.cornerRadius = 20
        layer.shadowRadius = 8
        layer.masksToBounds = true
        clipsToBounds = false
        contentHorizontalAlignment = .left
        layoutIfNeeded()
        contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        titleEdgeInsets.left = 0
            
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
