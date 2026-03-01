import SwiftUI
import SwiftData
import PhotosUI

struct FoodInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodPreference.usageCount, order: .reverse) private var foodPreferences: [FoodPreference]

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var parsedNutrition: NutritionInfo?
    @State private var errorMessage: String?
    @State private var showConfirmation = false

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
        isLoading = true
        errorMessage = nil

        do {
            let nutrition: NutritionInfo

            if let image = selectedImage {
                // Parse with image
                nutrition = try await aiService.parseFoodImage(image, additionalContext: inputText.isEmpty ? nil : inputText, preferences: foodPreferences)
            } else {
                // Parse text only
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

        inputText = ""
        selectedImage = nil
        selectedPhoto = nil
        parsedNutrition = nil
        showConfirmation = false
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
