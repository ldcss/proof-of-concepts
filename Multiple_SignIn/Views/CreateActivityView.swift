//
//  CreateActivityView.swift
//  Multiple_SignIn
//
//  Created by Lucas Daniel Costa da Silva on 01/09/25.
//

import SwiftUI
import PhotosUI

/// View for creating new activities (Father's role)
struct CreateActivityView: View {
    @StateObject private var viewModel: CreateActivityViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var showImagePicker = false
    
    init(family: Family) {
        self._viewModel = StateObject(wrappedValue: CreateActivityViewModel(family: family))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Activity Details Section
                Section("Activity Details") {
                    TextField("Activity Title", text: $viewModel.title)
                        .textInputAutocapitalization(.words)
                    
                    HStack {
                        Text("Goal Amount")
                        Spacer()
                        TextField("0.00", text: $viewModel.moneyGoal)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                    }
                    
                    DatePicker("End Date", selection: $viewModel.endDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }
                
                // Picture Section
                Section("Picture (Optional)") {
                    VStack {
                        if let selectedImage = viewModel.selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                                .cornerRadius(12)
                        } else {
                            Button(action: { showImagePicker = true }) {
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.blue)
                                    Text("Add Picture")
                                        .foregroundColor(.blue)
                                }
                                .frame(height: 100)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Assign to Family Members Section
                Section("Assign to Family Members") {
                    if viewModel.familyMembers.isEmpty {
                        Text("No family members found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.familyMembers, id: \.id) { member in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(member.name)
                                        .font(.headline)
                                    Text(member.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if viewModel.selectedMembers.contains(member) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleMemberSelection(member)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        viewModel.createActivity()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .photosPicker(
                isPresented: $showImagePicker,
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            viewModel.selectedImage = image
                        }
                    }
                }
            }
            .overlay(
                Group {
                    if viewModel.isLoading {
                        LoadingOverlay()
                    }
                }
            )
            .alert("Activity Created", isPresented: $viewModel.activityCreated) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your activity has been created successfully!")
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}