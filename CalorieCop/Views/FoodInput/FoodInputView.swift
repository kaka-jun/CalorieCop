import SwiftUI
import SwiftData
import PhotosUI

struct FoodInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodPreference.usageCount, order: .reverse) private var foodPreferences: [FoodPreference]

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var parsedNutrition: NutritionInfo?
    @State private var parsedNutritionList: [NutritionInfo] = []
    @State private var errorMessage: String?
    @State private var showConfirmation = false
    @State private var showMultipleConfirmation = false

    // Image picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingCameraAlert = false

    private let aiService = MiniMaxService()

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    instructionText

                    // Image input section
                    imageInputSection

                    // Dynamic divider text based on whether image is selected
                    if selectedImage != nil {
                        dividerWithText("补充说明 (可选)")
                    } else {
                        dividerWithText("或直接输入文字")
                    }

                    // Text input section
                    inputField

                    if let error = errorMessage {
                        errorView(error)
                    }

                    parseButton
                }
                .padding()
            }
            .navigationTitle("记录食物")
            .sheet(isPresented: $showConfirmation) {
                if let nutrition = parsedNutrition {
                    FoodConfirmationView(
                        rawInput: inputText.isEmpty ? "图片识别" : inputText,
                        originalNutrition: nutrition
                    ) { editedNutrition in
                        saveFoodEntry(with: editedNutrition)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $selectedImage)
            }
            .sheet(isPresented: $showMultipleConfirmation) {
                MultipleFoodConfirmationView(
                    nutritionList: parsedNutritionList,
                    onConfirm: { confirmedList in
                        saveMultipleFoodEntries(confirmedList)
                    }
                )
            }
            .alert("相机不可用", isPresented: $showingCameraAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("请在真机上使用相机功能，或从相册选择图片。")
            }
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside text field
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    private var instructionText: some View {
        Text("拍照识别食物，可配合文字补充说明")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var imageInputSection: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            selectedImage = nil
                            selectedPhoto = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .padding(8)
                    }
            } else {
                HStack(spacing: 16) {
                    // Camera button
                    Button {
                        if isCameraAvailable {
                            showingCamera = true
                        } else {
                            showingCameraAlert = true
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title)
                            Text("拍照")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Photo library button
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.title)
                            Text("相册")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private func dividerWithText(_ text: String) -> some View {
        HStack {
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
        }
    }

    private var inputField: some View {
        let placeholder = selectedImage != nil
            ? "补充说明：如份量、时间等（可选）"
            : "例如：一碗米饭、两个鸡蛋、昨天的晚餐"

        return TextField(placeholder, text: $inputText, axis: .vertical)
            .textFieldStyle(.plain)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .lineLimit(3...6)
    }

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var parseButton: some View {
        Button {
            Task {
                await parseFood()
            }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: selectedImage != nil ? "eye.fill" : "sparkles")
                    Text(selectedImage != nil ? "识别食物" : "解析食物")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canParse ? Color.blue : Color.gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canParse || isLoading)
    }

    private var canParse: Bool {
        !inputText.isEmpty || selectedImage != nil
    }

    private func parseFood() async {
        // Dismiss keyboard first
        _ = await MainActor.run {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        isLoading = true
        errorMessage = nil

        do {
            if let image = selectedImage {
                // Image parsing still returns single item
                let nutrition = try await aiService.parseFoodImage(image, additionalContext: inputText.isEmpty ? nil : inputText, preferences: foodPreferences)
                parsedNutrition = nutrition
                showConfirmation = true
            } else {
                // Text parsing supports multiple items
                let nutritionList = try await aiService.parseFoodInputMultiple(inputText, preferences: foodPreferences)

                if nutritionList.count == 1 {
                    // Single item - show normal confirmation
                    parsedNutrition = nutritionList.first
                    showConfirmation = true
                } else if nutritionList.count > 1 {
                    // Multiple items - show multiple confirmation
                    parsedNutritionList = nutritionList
                    showMultipleConfirmation = true
                } else {
                    errorMessage = "未能识别任何食物"
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveFoodEntry(with nutrition: NutritionInfo) {
        let entry = FoodEntry(rawInput: inputText.isEmpty ? "图片识别: \(nutrition.foodName)" : inputText, nutrition: nutrition)
        modelContext.insert(entry)

        // Explicitly save to ensure Dashboard updates immediately
        try? modelContext.save()

        // Reset state
        inputText = ""
        selectedImage = nil
        selectedPhoto = nil
        parsedNutrition = nil
        showConfirmation = false

        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func saveMultipleFoodEntries(_ nutritionList: [NutritionInfo]) {
        for nutrition in nutritionList {
            let entry = FoodEntry(rawInput: inputText, nutrition: nutrition)
            modelContext.insert(entry)
        }
        try? modelContext.save()

        inputText = ""
        selectedImage = nil
        selectedPhoto = nil
        parsedNutritionList = []
        showMultipleConfirmation = false

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Multiple Food Confirmation View

struct MultipleFoodConfirmationView: View {
    @Environment(\.dismiss) private var dismiss

    let nutritionList: [NutritionInfo]
    let onConfirm: ([NutritionInfo]) -> Void

    @State private var selectedItems: Set<Int>

    init(nutritionList: [NutritionInfo], onConfirm: @escaping ([NutritionInfo]) -> Void) {
        self.nutritionList = nutritionList
        self.onConfirm = onConfirm
        // Default: all items selected
        self._selectedItems = State(initialValue: Set(0..<nutritionList.count))
    }

    private var totalCalories: Double {
        selectedItems.reduce(0) { sum, index in
            sum + nutritionList[index].calories
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary header
                VStack(spacing: 8) {
                    Text("识别到 \(nutritionList.count) 种食物")
                        .font(.headline)
                    Text("总热量: \(Int(totalCalories)) kcal")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))

                // Food list
                List {
                    ForEach(Array(nutritionList.enumerated()), id: \.offset) { index, nutrition in
                        MultipleFoodRow(
                            nutrition: nutrition,
                            isSelected: selectedItems.contains(index),
                            onToggle: {
                                if selectedItems.contains(index) {
                                    selectedItems.remove(index)
                                } else {
                                    selectedItems.insert(index)
                                }
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("确认食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认 (\(selectedItems.count))") {
                        let confirmed = selectedItems.sorted().map { nutritionList[$0] }
                        onConfirm(confirmed)
                        dismiss()
                    }
                    .disabled(selectedItems.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct MultipleFoodRow: View {
    let nutrition: NutritionInfo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .blue : .gray)
                .font(.title2)

            // Food info
            VStack(alignment: .leading, spacing: 4) {
                Text(nutrition.foodName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("\(Int(nutrition.grams))g")
                    Text("•")
                    Text("\(Int(nutrition.calories)) kcal")
                        .foregroundStyle(.orange)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("蛋白\(String(format: "%.1f", nutrition.protein))g")
                    Text("碳水\(String(format: "%.1f", nutrition.carbohydrates))g")
                    Text("脂肪\(String(format: "%.1f", nutrition.fat))g")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    FoodInputView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
