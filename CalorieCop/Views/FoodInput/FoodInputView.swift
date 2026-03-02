import SwiftUI
import SwiftData
import PhotosUI

struct FoodInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodPreference.usageCount, order: .reverse) private var foodPreferences: [FoodPreference]
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var recentEntries: [FoodEntry]

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var parsedNutrition: NutritionInfo?
    @State private var errorMessage: String?
    @State private var showConfirmation = false
    @State private var showTextInput = false

    // Image picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingCameraAlert = false

    private let aiService = MiniMaxService()

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    // Get recent unique foods (last 10)
    private var recentFoods: [FoodEntry] {
        var seen = Set<String>()
        return recentEntries.filter { entry in
            guard !seen.contains(entry.foodName) else { return false }
            seen.insert(entry.foodName)
            return true
        }.prefix(10).map { $0 }
    }

    // Matching foods based on input text
    private var matchingFoods: [FoodEntry] {
        if inputText.isEmpty {
            return []
        }
        return recentFoods.filter {
            $0.foodName.localizedCaseInsensitiveContains(inputText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Input methods (camera, photo, text)
                    cameraSection

                    // Text input (shown when no image selected)
                    if showTextInput || selectedImage != nil {
                        textInputSection

                        // Matching foods when typing
                        if !matchingFoods.isEmpty && selectedImage == nil {
                            matchingFoodsSection
                        }
                    }

                    if let error = errorMessage {
                        errorView(error)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                        showTextInput = true
                    }
                }
            }
        }
    }

    private var cameraSection: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                // Show selected image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
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

                // Parse button
                Button {
                    Task { await parseFood() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "eye.fill")
                            Text("识别食物")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)
            } else {
                // Three input method cards
                HStack(spacing: 12) {
                    // Camera card
                    InputMethodCard(
                        icon: "camera.fill",
                        title: "拍照",
                        color: .blue,
                        isSelected: false
                    ) {
                        if isCameraAvailable {
                            showingCamera = true
                        } else {
                            showingCameraAlert = true
                        }
                    }

                    // Photo library card
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        InputMethodCardContent(
                            icon: "photo.fill",
                            title: "相册",
                            color: .green,
                            isSelected: false
                        )
                    }

                    // Text input card
                    InputMethodCard(
                        icon: "keyboard",
                        title: "文字",
                        color: .orange,
                        isSelected: showTextInput
                    ) {
                        showTextInput.toggle()
                    }
                }

                // Mascot speech bubble
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Text("拍照或输入文字记录你的饮食~")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Image("mascot_avatar")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4)
                }
            }
        }
    }

    private var textInputSection: some View {
        VStack(spacing: 12) {
            if selectedImage == nil {
                Text("描述你吃的食物")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TextField(
                selectedImage != nil ? "补充说明（可选）" : "例如：一碗米饭、两个鸡蛋",
                text: $inputText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .lineLimit(2...4)

            if selectedImage == nil && !inputText.isEmpty {
                Button {
                    Task { await parseFood() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                            Text("解析食物")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)
            }
        }
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

    private var matchingFoodsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("匹配的食物")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(matchingFoods) { entry in
                    RecentFoodRow(entry: entry) {
                        quickAddFood(entry)
                    }
                    if entry.id != matchingFoods.last?.id {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }


    private func quickAddFood(_ entry: FoodEntry) {
        let newEntry = FoodEntry(
            rawInput: "快速添加: \(entry.foodName)",
            foodName: entry.foodName,
            grams: entry.grams,
            calories: entry.calories,
            protein: entry.protein,
            carbohydrates: entry.carbohydrates,
            fat: entry.fat
        )
        modelContext.insert(newEntry)
        try? modelContext.save()
    }

    private func parseFood() async {
        _ = await MainActor.run {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        isLoading = true
        errorMessage = nil

        do {
            let nutrition: NutritionInfo

            if let image = selectedImage {
                nutrition = try await aiService.parseFoodImage(image, additionalContext: inputText.isEmpty ? nil : inputText, preferences: foodPreferences)
            } else {
                nutrition = try await aiService.parseFoodInput(inputText, preferences: foodPreferences)
            }

            parsedNutrition = nutrition
            showConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveFoodEntry(with nutrition: NutritionInfo) {
        let entry = FoodEntry(rawInput: inputText.isEmpty ? "图片识别: \(nutrition.foodName)" : inputText, nutrition: nutrition)
        modelContext.insert(entry)
        try? modelContext.save()

        inputText = ""
        selectedImage = nil
        selectedPhoto = nil
        parsedNutrition = nil
        showConfirmation = false
        showTextInput = false

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Recent Food Row

struct RecentFoodRow: View {
    let entry: FoodEntry
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Food icon
            Text(foodEmoji(for: entry.foodName))
                .font(.title)
                .frame(width: 44, height: 44)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(Int(entry.calories))kcal/\(Int(entry.grams))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
    }

    private func foodEmoji(for name: String) -> String {
        let emojiMap: [String: String] = [
            "米饭": "🍚", "面条": "🍜", "鸡蛋": "🥚", "牛奶": "🥛",
            "苹果": "🍎", "香蕉": "🍌", "鸡肉": "🍗", "牛肉": "🥩",
            "沙拉": "🥗", "面包": "🍞", "咖啡": "☕️", "酸奶": "🥛",
            "鱼": "🐟", "虾": "🦐", "蔬菜": "🥬", "玉米": "🌽"
        ]

        for (key, emoji) in emojiMap {
            if name.contains(key) {
                return emoji
            }
        }
        return "🍽️"
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

// MARK: - Input Method Card

struct InputMethodCard: View {
    let icon: String
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            InputMethodCardContent(icon: icon, title: title, color: color, isSelected: isSelected)
        }
    }
}

struct InputMethodCardContent: View {
    let icon: String
    let title: String
    let color: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(isSelected ? .white : color)

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(isSelected ? color : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? color : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    FoodInputView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
