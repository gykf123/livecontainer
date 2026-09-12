//
//  LCCalculatorDisguiseView.swift
//  LiveContainerSwiftUI
//
//  计算器伪装界面：外观与功能均模仿 iOS 自带“计算器”。
//  正常可用作计算器；当计算结果（或输入值）等于设置的密码时，
//  按下“=”即可解锁并进入 LiveContainer 本体。
//

import Foundation
import SwiftUI

struct LCCalculatorDisguiseView: View {
    @StateObject private var lock = LCCalculatorLock.shared
    
    @State private var display = "0"
    @State private var accumulator: Double? = nil      // 左操作数
    @State private var pendingOp: Operation? = nil
    @State private var waitingForNewNumber = true      // 下一次输入是否重新开始一个数字
    
    // MARK: - 运算类型
    private enum Operation: String {
        case add = "+"
        case subtract = "−"
        case multiply = "×"
        case divide = "÷"
    }
    
    // MARK: - 按键类型
    private enum CalcKey: Hashable {
        case digit(String)
        case dot
        case add, subtract, multiply, divide, equals
        case ac, plusMinus, percent
        
        var title: String {
            switch self {
            case .digit(let d): return d
            case .dot: return "."
            case .add: return "+"
            case .subtract: return "−"
            case .multiply: return "×"
            case .divide: return "÷"
            case .equals: return "="
            case .ac: return "AC"
            case .plusMinus: return "±"
            case .percent: return "%"
            }
        }
        
        var isOperation: Bool {
            switch self {
            case .add, .subtract, .multiply, .divide, .equals: return true
            default: return false
            }
        }
        
        var isFunction: Bool {
            switch self {
            case .ac, .plusMinus, .percent: return true
            default: return false
            }
        }
        
        var isWideZero: Bool {
            if case .digit(let d) = self, d == "0" { return true }
            return false
        }
    }
    
    private var currentDouble: Double { Double(display) ?? 0 }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            let padding: CGFloat = 12
            let gap: CGFloat = 12
            let buttonSize = (geo.size.width - padding * 2 - gap * 3) / 4
            let displayHeight = max(geo.size.height * 0.30, 120)
            
            VStack(spacing: gap) {
                Spacer(minLength: displayHeight * 0.25)
                
                // 显示屏
                HStack {
                    Spacer()
                    Text(display)
                        .font(.system(size: min(buttonSize * 0.95, 92), weight: .thin))
                        .foregroundColor(.white)
                        .padding(.horizontal, padding)
                        .lineLimit(1)
                        .minimumScaleFactor(0.25)
                }
                .frame(height: displayHeight)
                
                makeRow([.ac, .plusMinus, .percent, .divide], buttonSize: buttonSize, gap: gap)
                makeRow([.digit("7"), .digit("8"), .digit("9"), .multiply], buttonSize: buttonSize, gap: gap)
                makeRow([.digit("4"), .digit("5"), .digit("6"), .subtract], buttonSize: buttonSize, gap: gap)
                makeRow([.digit("1"), .digit("2"), .digit("3"), .add], buttonSize: buttonSize, gap: gap)
                makeRow([.digit("0"), .dot, .equals], buttonSize: buttonSize, gap: gap)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .background(Color.black.ignoresSafeArea())
        }
    }
    
    // MARK: - 布局
    @ViewBuilder
    private func makeRow(_ keys: [CalcKey], buttonSize: CGFloat, gap: CGFloat) -> some View {
        HStack(spacing: gap) {
            ForEach(keys, id: \.self) { key in
                if key.isWideZero {
                    calcButton(key, width: buttonSize * 2 + gap, height: buttonSize)
                } else {
                    calcButton(key, width: buttonSize, height: buttonSize)
                }
            }
        }
    }
    
    private func calcButton(_ key: CalcKey, width: CGFloat, height: CGFloat) -> some View {
        Button(action: { handleTap(key) }) {
            Text(key.title)
                .font(.system(size: min(width, height) * 0.42, weight: .regular))
                .frame(width: width, height: height)
                .foregroundColor(buttonForegroundColor(key))
                .background(
                    Group {
                        if key.isWideZero {
                            Capsule().fill(buttonBackgroundColor(key))
                        } else {
                            Circle().fill(buttonBackgroundColor(key))
                        }
                    }
                )
        }
    }
    
    private func buttonBackgroundColor(_ key: CalcKey) -> Color {
        if key.isFunction { return Color(white: 0.6) }
        if key.isOperation {
            if let pending = pendingOp, operationForKey(key) == pending {
                return Color.white
            }
            return Color.orange
        }
        return Color(white: 0.2)
    }
    
    private func buttonForegroundColor(_ key: CalcKey) -> Color {
        if key.isFunction { return .black }
        if key.isOperation, let pending = pendingOp, operationForKey(key) == pending {
            return Color.orange
        }
        return .white
    }
    
    // MARK: - 交互逻辑
    private func handleTap(_ key: CalcKey) {
        switch key {
        case .digit(let d): tapDigit(d)
        case .dot: tapDot()
        case .add: tapOperation(.add)
        case .subtract: tapOperation(.subtract)
        case .multiply: tapOperation(.multiply)
        case .divide: tapOperation(.divide)
        case .equals: tapEquals()
        case .ac: tapAC()
        case .plusMinus: tapPlusMinus()
        case .percent: tapPercent()
        }
    }
    
    private func tapDigit(_ d: String) {
        if waitingForNewNumber {
            display = d
            waitingForNewNumber = false
        } else if display == "0" {
            display = d
        } else if display.count < 9 {
            display += d
        }
    }
    
    private func tapDot() {
        if waitingForNewNumber {
            display = "0."
            waitingForNewNumber = false
        } else if !display.contains(".") {
            display += "."
        }
    }
    
    private func tapOperation(_ op: Operation) {
        let current = currentDouble
        if let acc = accumulator, let pending = pendingOp, !waitingForNewNumber {
            let result = apply(acc, current, pending)
            accumulator = result
            display = format(result)
        } else {
            accumulator = current
        }
        pendingOp = op
        waitingForNewNumber = true
    }
    
    private func tapEquals() {
        let current = currentDouble
        if let acc = accumulator, let pending = pendingOp {
            let rhs = waitingForNewNumber ? acc : current
            let result = apply(acc, rhs, pending)
            let resultStr = format(result)
            display = resultStr
            accumulator = nil
            pendingOp = nil
            waitingForNewNumber = true
            if resultStr == lock.password {
                lock.tryUnlock(with: resultStr)
            }
            return
        }
        // 没有待运算：当前显示即为输入值
        if display == lock.password {
            lock.tryUnlock(with: display)
        }
        waitingForNewNumber = true
    }
    
    private func tapAC() {
        display = "0"
        accumulator = nil
        pendingOp = nil
        waitingForNewNumber = true
    }
    
    private func tapPlusMinus() {
        if display == "0" || display == "0." { return }
        if display.hasPrefix("-") {
            display.removeFirst()
        } else {
            display = "-" + display
        }
    }
    
    private func tapPercent() {
        if let v = Double(display) {
            display = format(v / 100)
        }
        waitingForNewNumber = false
    }
    
    // MARK: - 计算辅助
    private func operationForKey(_ key: CalcKey) -> Operation? {
        switch key {
        case .add: return .add
        case .subtract: return .subtract
        case .multiply: return .multiply
        case .divide: return .divide
        default: return nil
        }
    }
    
    private func apply(_ a: Double, _ b: Double, _ op: Operation) -> Double {
        switch op {
        case .add: return a + b
        case .subtract: return a - b
        case .multiply: return a * b
        case .divide: return b == 0 ? 0 : a / b
        }
    }
    
    private func format(_ value: Double) -> String {
        if value.isInfinite || value.isNaN { return "0" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        let str = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        if str.count > 9 {
            return String(format: "%.6g", value)
        }
        return str
    }
}