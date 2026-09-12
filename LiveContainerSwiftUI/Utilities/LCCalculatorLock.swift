//
//  LCCalculatorLock.swift
//  LiveContainerSwiftUI
//
//  计算器伪装锁：管理“本体”是否解锁，以及密码的读取与修改。
//  默认密码为 1234，可在应用内（设置页）更改。
//

import Foundation
import SwiftUI

/// 全局唯一的计算器伪装锁管理器。
/// - 启动时应用显示计算器界面；输入正确密码并按“=”后解锁进入 LiveContainer 本体。
/// - 密码保存在 UserDefaults（standard），默认 "1234"。
final class LCCalculatorLock: ObservableObject {
    static let shared = LCCalculatorLock()
    
    /// 密码在 UserDefaults 中保存的键。
    static let passwordKey = "LCCalculatorLockPassword"
    
    /// 是否为“本体”已解锁状态。
    @Published var isUnlocked: Bool = false
    
    private init() {}
    
    /// 当前生效的密码。若未设置或为空，回退到默认 "1234"。
    var password: String {
        let stored = UserDefaults.standard.string(forKey: LCCalculatorLock.passwordKey)
        if let stored, !stored.isEmpty {
            return stored
        }
        return "1234"
    }
    
    /// 尝试用“输入的数字串”解锁。匹配成功返回 true。
    /// - Parameter entered: 计算器当前显示的数字串。
    func tryUnlock(with entered: String) -> Bool {
        guard !entered.isEmpty, entered == password else { return false }
        isUnlocked = true
        return true
    }
    
    /// 修改密码并写入 UserDefaults。
    /// 仅接受最长 12 位的数字串（计算器只能输入数字）。
    /// - Returns: 修改是否成功。
    @discardableResult
    func changePassword(_ newPassword: String) -> Bool {
        let trimmed = newPassword.filter { $0.isNumber }
        guard (1...12).contains(trimmed.count) else { return false }
        UserDefaults.standard.set(trimmed, forKey: LCCalculatorLock.passwordKey)
        return true
    }
    
    /// 重新上锁（例如应用进入后台时调用，保证下次打开仍显示计算器伪装）。
    func lock() {
        isUnlocked = false
    }
}