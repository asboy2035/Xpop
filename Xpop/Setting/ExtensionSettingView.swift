//
//  ExtensionSettingView.swift
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/17.
//

import SwiftUI

struct PluginConfigurationView: View {
    private var name: String!
    private var identifier: String!
    private var options: [Option]
    @State private var contentHeight: CGFloat = 0
    @State private var optionValues: [[String: String]]

    @Environment(\.dismiss) var dismiss

    init(name: String!, identifier: String!, options: [Option], optionValues: [[String: String]]) {
        self.name = name
        self.identifier = identifier
        self.options = options
        // 初始化 optionValues，但这仍然是一个空数组，初始化时不会对其做修改
        self._optionValues = State(initialValue: optionValues)
    }

    var body: some View {
        VStack {
            Text("Setting for \(name)")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 8)

            GeometryReader { _ in
                ScrollView {
                    VStack {
                        ForEach(options.indices, id: \.self) { index in
                            Section {
                                OptionView(
                                    optionValue: Binding<[String: String]>(
                                        get: { optionValues[index] },
                                        set: { newValue in
                                            optionValues[index] = newValue
                                        }
                                    ),
                                    option: options[index]
                                )
                            }
                            .padding(.bottom, 10)
                        }
                    }
                    .background(GeometryReader { innerGeometry in
                        Color.clear.onAppear {
                            self.contentHeight = innerGeometry.size.height
                        }
                    })
                }
                .frame(height: min(self.contentHeight, 300))
            }
            .frame(height: min(self.contentHeight, 300))

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .padding(.horizontal)

                Button("Save") {
                    saveOptions()
                    dismiss()
                }
                .padding(.horizontal)
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: 300)
        .onAppear {
            loadOptions() // 在视图呈现之前加载选项
        }
    }

    private func saveOptions() {
        UserDefaults.standard.set(optionValues, forKey: "\(identifier!)-options")
    }

    private func loadOptions() {
        // 这里可以确保在视图加载之前初始化 optionValues
        if let savedOptions = UserDefaults.standard.array(forKey: "\(identifier!)-options") as? [[String: String]] {
            optionValues = savedOptions
        }

        if optionValues.isEmpty {
            optionValues = options.map { option in
                var value: String = ""
                if let defaultValue = option.defaultValue {
                    value = defaultValue
                } else if let firstValue = option.values?.first {
                    value = firstValue
                }
                return [
                    "type": option.type,
                    "label": option.label,
                    "value": value,
                ]
            }
        }
    }
}

struct OptionView: View {
    @Binding var optionValue: [String: String]
    var option: Option

    // 初始化方法
    init(optionValue: Binding<[String: String]>, option: Option) {
        self._optionValue = optionValue
        self.option = option
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch option.type {
            case "string":
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .padding(.leading, 16)
                    TextField("", text: Binding<String>(
                        get: { optionValue["value"]!  },
                        set: { optionValue["value"] = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                }
            case "boolean":
                HStack {
                    Text(option.label)
                        .padding(.leading, 16)
                    Spacer()
//                    if let boolValue = optionValue["value"] as? Bool {
//                        Toggle("", isOn: Binding<Bool>(
//                            get: { boolValue },
//                            set: { optionValue = $0 }
//                        ))
//                        .padding(.trailing, 16)
//                    }
                }
            case "multiple":
                HStack {
                    Text(option.label)
                        .padding(.leading, 16)

                    Spacer()

//                    if let selectedValue = optionValue as? String {
//                        Picker("", selection: Binding<String>(
//                            get: { selectedValue },
//                            set: { optionValue = $0 }
//                        )) {
//                            ForEach(option.values ?? [], id: \.self) { value in
//                                Text(option.valueLabels?[option.values?.firstIndex(of: value) ?? 0] ?? value)
//                                    .tag(value)
//                            }
//                        }
//                        .pickerStyle(MenuPickerStyle())
//                        .frame(width: 150)
//                        .padding(.trailing, 16)
//                    }
                }
            default:
                Text(option.type)
            }
        }
    }
}
