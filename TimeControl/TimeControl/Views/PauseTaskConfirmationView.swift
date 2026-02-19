//
//  PauseTaskConfirmationView.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI

struct PauseTaskConfirmationView: View {
    let onPause: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Pause Task?")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("Do you want to pause the task timer?")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button(action: {
                    onCancel()
                }) {
                    Text("Cancel")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                
                Button(action: {
                    onPause()
                }) {
                    Text("Pause Task")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .frame(width: 300, height: 150)
    }
}
