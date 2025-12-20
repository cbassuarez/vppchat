//
//  WebRetrievalPolicyRow.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/19/25.
//


import SwiftUI

struct WebRetrievalPolicyRow: View {
  @AppStorage("WebRetrievalPolicy") private var webPolicyRaw: String = WebRetrievalPolicy.auto.rawValue

  private var policy: WebRetrievalPolicy {
    get { WebRetrievalPolicy(rawValue: webPolicyRaw) ?? .auto }
    set { webPolicyRaw = newValue.rawValue }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Web Retrieval Policy")
        .font(.system(size: 12, weight: .semibold))
        .textCase(.uppercase)

         var policyBinding: Binding<WebRetrievalPolicy> {
          Binding(
            get: { WebRetrievalPolicy(rawValue: webPolicyRaw) ?? .auto },
            set: { webPolicyRaw = $0.rawValue }
          )
        }
        Picker("", selection: policyBinding) {
            Text("Auto").tag(WebRetrievalPolicy.auto)
            Text("Always").tag(WebRetrievalPolicy.always)
          }

      .pickerStyle(.segmented)

      Text("Auto: only fetch when needed. Always: prefer fetching whenever Web access is On.")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
  }
}
