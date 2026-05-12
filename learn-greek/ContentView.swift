//
//  ContentView.swift
//  learn-greek
//
//  Created by Leonidas von Bothmer on 30.04.26.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = ReviewSessionViewModel()
    @State private var isFocusMode = false
    @State private var isFocusDisclaimerVisible = true
    @State private var focusDisclaimerHideTask: Task<Void, Never>?
    @State private var translation: CGSize = .zero
    @State private var isFlipped = false
    @State private var touchMoved = false
    @State private var isCommittingSwipe = false
    @State private var isEditing = false
    @State private var isDeleteConfirmationPresented = false
    @State private var draftFrontText = ""
    @State private var draftEnglishText = ""
    @State private var draftGermanText = ""
    @State private var draftCard: VocabCardState?
    @State private var isAddingNewCard = false
    @State private var frontEditorSize: CGSize = .zero
    @State private var backEditorSize: CGSize = .zero
    @State private var frontEditorFontSize: CGFloat = 42
    @State private var backEditorFontSize: CGFloat = 42
    @State private var frontFlipAxisTiltDegrees = Double.random(in: -2 ... 2)
    @State private var backFlipAxisTiltDegrees = Double.random(in: -2 ... 2)
    @State private var activeFlipAxisTiltDegrees = Double.random(in: -2 ... 2)
    @State private var stackFrames: [LearningStack: CGRect] = [:]
    @State private var cardFrame: CGRect = .zero
    @State private var addButtonFrame: CGRect = .zero
    @State private var trashButtonFrame: CGRect = .zero
    @State private var entrySourceFrameOverride: CGRect?
    @State private var entryOffset: CGSize = .zero
    @State private var entryScale: CGFloat = 1
    @State private var editTransitionScale: CGFloat = 1
    @State private var departureOffset: CGSize = .zero
    @State private var departureScale: CGFloat = 1
    @State private var departureOpacity: Double = 1
    @State private var pressShrinkScale: CGFloat = 1
    @State private var pressShrinkAnchor: UnitPoint = .center
    @State private var pressTiltAnchor: UnitPoint = .center
    @State private var pressTiltXDegrees: Double = 0
    @State private var pressTiltYDegrees: Double = 0
    @State private var cancelShakeDegrees: Double = 0
    @State private var saveGlowScale: CGFloat = 0.96
    @State private var saveGlowOpacity: Double = 0
    @State private var saveGlowBlur: CGFloat = 10
    @State private var transferSourceStack: LearningStack?
    @State private var transferDestinationStack: LearningStack?
    @State private var transferSourcePulse: CGFloat = 0
    @State private var transferDestinationPulse: CGFloat = 0
    @Namespace private var editControlsNamespace
    @State private var isEditorFocused = false

    private struct CardMetrics {
        let baseWidth: CGFloat
        let baseHeight: CGFloat
        let activeWidth: CGFloat
        let activeHeight: CGFloat

        var activeSize: CGSize {
            CGSize(width: activeWidth, height: activeHeight)
        }
    }

    private var flipRotation: Double {
        isFlipped ? 180 : 0
    }

    private var flipAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        let tiltRadians = activeFlipAxisTiltDegrees * .pi / 180
        return (
            x: CGFloat(sin(tiltRadians)),
            y: CGFloat(cos(tiltRadians)),
            z: 0
        )
    }

    private var dragRollDegrees: Double {
        guard !isEditing else { return 0 }
        return Double(translation.width / 14)
    }

    private var chromeInset: CGFloat {
        16
    }

    private var controlButtonSpacing: CGFloat {
        32
    }

    private var controlStep: CGFloat {
        44 + controlButtonSpacing
    }

    private var toolbarControlSize: CGFloat {
        48
    }

    private var saveGlowColor: Color {
        Color(red: 0.22, green: 0.22, blue: 0.98)
    }

    private var hasPendingEdits: Bool {
        guard let item = presentedCard?.item else { return false }

        let trimmedGreek = draftFrontText.trimmingCharacters(in: .whitespacesAndNewlines)
        let englishLines = normalizedLines(from: draftEnglishText)
        let germanLines = normalizedLines(from: draftGermanText)

        return trimmedGreek != item.greek
            || englishLines != item.english
            || germanLines != item.german
    }

    private var canSaveDraftCard: Bool {
        let trimmedGreek = draftFrontText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasBackContent = !normalizedLines(from: draftEnglishText).isEmpty
        return !trimmedGreek.isEmpty && hasBackContent
    }

    private var isEditingExistingCard: Bool {
        isEditing && !isAddingNewCard
    }

    private var presentedCard: VocabCardState? {
        draftCard ?? viewModel.currentCard
    }

    private var saveButtonEnabled: Bool {
        canSaveDraftCard && (isAddingNewCard || hasPendingEdits)
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = cardMetrics(for: proxy)

            ZStack {
                reviewBackgroundColor
                    .ignoresSafeArea()

                if isFocusMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .simultaneousGesture(
                            TapGesture(count: 1).onEnded {
                                showFocusDisclaimerFor12Seconds()
                            }
                        )
                        .onTapGesture(count: 2) {
                            exitFocusMode()
                        }
                }

                cardSection(metrics: metrics)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: isEditing ? .top : .center
                    )
                    .ignoresSafeArea(.keyboard, edges: isEditing ? .bottom : [])
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !isFocusMode && !isEditing {
                    stackSummaryRow
                        .padding(.top, chromeInset)
                        .frame(maxWidth: .infinity)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isFocusMode && !isEditing {
                    editControls
                        .padding(.horizontal, 36)
                        .padding(.bottom, 0)
                }
            }
            .overlay(alignment: .bottom) {
                if isFocusMode && isFocusDisclaimerVisible {
                    focusModeDisclaimerBar
                        .padding(.bottom, chromeInset)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .coordinateSpace(name: "reviewSpace")
            .onPreferenceChange(StackFramePreferenceKey.self) { frames in
                stackFrames.merge(frames) { _, new in new }
            }
            .onPreferenceChange(CardFramePreferenceKey.self) { frame in
                cardFrame = frame
            }
            .onChange(of: viewModel.lastStackTransfer) { _, transfer in
                guard let transfer else { return }
                runStackTransferAnimation(transfer)
            }
        }
    }

    private var stackSummaryRow: some View {
        HStack(spacing: 12) {
            ForEach(LearningStack.allCases, id: \.self) { stack in
                StatPill(
                    title: stack.title,
                    count: viewModel.countsByStack[stack] ?? 0,
                    color: pillColor(stack),
                    inwardPulse: transferSourceStack == stack ? transferSourcePulse : 0,
                    outwardPulse: transferDestinationStack == stack ? transferDestinationPulse : 0
                )
                .background(
                    GeometryReader { pillProxy in
                        Color.clear
                            .preference(
                                key: StackFramePreferenceKey.self,
                                value: [stack: pillProxy.frame(in: .named("reviewSpace"))]
                            )
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func cardSection(metrics: CardMetrics) -> some View {
        if let card = presentedCard {
            presentedCardView(for: card, metrics: metrics)
        } else {
            Text("No cards available")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func presentedCardView(for card: VocabCardState, metrics: CardMetrics) -> some View {
        cardView(for: card, cardSize: metrics.activeSize)
            .frame(width: metrics.activeWidth, height: metrics.activeHeight)
            .ignoresSafeArea(edges: isEditing ? .top : [])
            .background(cardFrameReader)
            .scaleEffect(departureScale)
            .opacity(departureOpacity)
            .offset(departureOffset)
            .modifier(CardMotionModifier(
                entryScale: entryScale,
                editTransitionScale: editTransitionScale,
                pressShrinkScale: pressShrinkScale,
                pressShrinkAnchor: pressShrinkAnchor,
                dragRollDegrees: dragRollDegrees,
                cancelShakeDegrees: cancelShakeDegrees,
                pressTiltXDegrees: pressTiltXDegrees,
                pressTiltYDegrees: pressTiltYDegrees,
                pressTiltAnchor: pressTiltAnchor,
                flipRotation: flipRotation,
                flipAxis: flipAxis,
                translation: translation,
                entryOffset: entryOffset,
                isEditing: isEditing
            ))
            .animation(.spring(response: 0.22, dampingFraction: 0.86), value: translation)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: isFlipped)
            .animation(.easeIn(duration: 0.18), value: isEditing)
            .animation(.spring(response: 0.5, dampingFraction: 0.84), value: entryOffset)
            .animation(.spring(response: 0.5, dampingFraction: 0.84), value: entryScale)
            .onChange(of: viewModel.cardPresentationID) { _, _ in
                if !isAddingNewCard {
                    resetPresentedCardState()
                }
            }
            .onAppear {
                preparePresentedCard(using: card.item)
            }
            .onChange(of: isEditing) { _, editing in
                animateEditTransition(editing: editing)
                if editing {
                    focusVisibleEditor(after: 0.05)
                } else {
                    dismissEditorKeyboard()
                }
            }
    }

    private var cardFrameReader: some View {
        GeometryReader { cardProxy in
            Color.clear
                .preference(
                    key: CardFramePreferenceKey.self,
                    value: cardProxy.frame(in: .named("reviewSpace"))
                )
        }
    }

    private func commitSwipe(correct: Bool) {
        guard !isCommittingSwipe else { return }
        isCommittingSwipe = true
        let offscreenX: CGFloat = correct ? 700 : -700

        withAnimation(.spring(response: 0.2, dampingFraction: 0.84)) {
            translation = CGSize(width: offscreenX, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            if correct {
                viewModel.markCorrect()
            } else {
                viewModel.markWrong()
            }
        }
    }

    @ViewBuilder
    private func cardView(for card: VocabCardState, cardSize: CGSize) -> some View {
        if isEditing {
            cardSurface(for: card)
        } else {
            cardSurface(for: card)
                .gesture(dragGesture(cardSize: cardSize))
        }
    }

    private var focusModeDisclaimerBar: some View {
        Text("Double tap background\nto leave focus mode")
            .font(.footnote.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(UIColor.systemGray3))
            .padding(.horizontal, 24)
            .lineLimit(2)
            .minimumScaleFactor(0.88)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                exitFocusMode()
            }
            .accessibilityHint("Double tap the background outside the card to leave focus mode.")
    }

    private func enterFocusMode() {
        guard viewModel.currentCard != nil else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isFocusMode = true
        }
        showFocusDisclaimerFor12Seconds()
    }

    private func exitFocusMode() {
        cancelFocusDisclaimerHideTask()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isFocusMode = false
            isFocusDisclaimerVisible = true
        }
    }

    private func showFocusDisclaimerFor12Seconds() {
        guard isFocusMode else { return }
        cancelFocusDisclaimerHideTask()
        withAnimation(.easeOut(duration: 0.2)) {
            isFocusDisclaimerVisible = true
        }
        focusDisclaimerHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                isFocusDisclaimerVisible = false
            }
            focusDisclaimerHideTask = nil
        }
    }

    private func cancelFocusDisclaimerHideTask() {
        focusDisclaimerHideTask?.cancel()
        focusDisclaimerHideTask = nil
    }

    private func dragGesture(cardSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isEditing else { return }
                let adjustedTranslation = adjustedDragTranslation(for: value.translation)
                updatePressInteraction(with: value, cardSize: cardSize)

                if !isCommittingSwipe {
                    translation = adjustedTranslation
                }
                if hypot(adjustedTranslation.width, adjustedTranslation.height) > 8 {
                    touchMoved = true
                }
            }
            .onEnded { value in
                guard !isEditing else { return }
                let swipeThreshold: CGFloat = 90
                let adjustedTranslation = adjustedDragTranslation(for: value.translation)
                let wasTap = !touchMoved && hypot(adjustedTranslation.width, adjustedTranslation.height) < 8

                resetPressInteraction(animated: true)

                if wasTap {
                    toggleFlip()
                } else if adjustedTranslation.width > swipeThreshold {
                    commitSwipe(correct: true)
                } else if adjustedTranslation.width < -swipeThreshold {
                    commitSwipe(correct: false)
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        translation = .zero
                    }
                }

                touchMoved = false
            }
    }

    private func adjustedDragTranslation(for translation: CGSize) -> CGSize {
        guard isFlipped else { return translation }
        return CGSize(width: -translation.width, height: translation.height)
    }

    private func cardMetrics(for proxy: GeometryProxy) -> CardMetrics {
        let size = proxy.size
        let baseWidth = min(size.width * 0.86, 420)
        let baseHeight = min(size.height * 0.62, 620)
        let activeWidth = isEditing ? size.width : baseWidth
        let activeHeight = isEditing ? size.height * 1.65 : baseHeight

        return CardMetrics(
            baseWidth: baseWidth,
            baseHeight: baseHeight,
            activeWidth: activeWidth,
            activeHeight: activeHeight
        )
    }

    private func cardSurface(for card: VocabCardState) -> some View {
        let cornerRadius: CGFloat = isEditing ? 0 : 28
        let shadowOpacity = isEditing ? 0 : 0.08
        let shadowRadius: CGFloat = isEditing ? 0 : 24
        let shadowYOffset: CGFloat = isEditing ? 0 : 10

        return ZStack(alignment: .bottomTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(saveGlowColor.opacity(0.42))
                    .scaleEffect(saveGlowScale)
                    .opacity(saveGlowOpacity * 0.82)
                    .blur(radius: saveGlowBlur)

                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .strokeBorder(saveGlowColor.opacity(0.92), lineWidth: 10)
                    .scaleEffect(saveGlowScale * 0.99)
                    .opacity(saveGlowOpacity)
                    .blur(radius: saveGlowBlur * 0.72)
            }
            .blendMode(.plusLighter)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: shadowYOffset)

            if isEditing {
                Color.clear
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .onTapGesture {
                        toggleFlip()
                    }
            }

            readOnlyCardContent(for: card.item)
                .opacity(isEditing ? 0 : 1)

            editorContent(for: card.item)
                .opacity(isEditing ? 1 : 0)
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func readOnlyCardContent(for item: VocabItem) -> some View {
        ZStack {
            cardFaceText(item.greek)
                .opacity(isFlipped ? 0 : 1)

            cardBackFaceText(backText(for: item))
                .opacity(isFlipped ? 1 : 0)
        }
    }

    @ViewBuilder
    private func editorContent(for item: VocabItem) -> some View {
        GeometryReader { proxy in
            let shrinkThresholdSize = CGSize(
                width: proxy.size.width * 0.75,
                height: proxy.size.height * 0.75
            )
            let activeText = Binding<String>(
                get: { isFlipped ? draftEnglishText : draftFrontText },
                set: { newValue in
                    if isFlipped {
                        draftEnglishText = newValue
                    } else {
                        draftFrontText = newValue
                    }
                }
            )
            let activeMeasuredSize = Binding<CGSize>(
                get: { isFlipped ? backEditorSize : frontEditorSize },
                set: { newValue in
                    if isFlipped {
                        backEditorSize = newValue
                    } else {
                        frontEditorSize = newValue
                    }
                }
            )
            let activeFontSize = Binding<CGFloat>(
                get: { isFlipped ? backEditorFontSize : frontEditorFontSize },
                set: { newValue in
                    if isFlipped {
                        backEditorFontSize = newValue
                    } else {
                        frontEditorFontSize = newValue
                    }
                }
            )

            editableField(
                text: activeText,
                prompt: isFlipped ? "English" : "Greek",
                measuredSize: activeMeasuredSize,
                fontSize: activeFontSize,
                shrinkThresholdSize: shrinkThresholdSize,
                isFocused: Binding(
                    get: { isEditorFocused },
                    set: { isEditorFocused = $0 }
                )
            )
        }
        .padding(.horizontal, 26)
    }

    private func editableField(
        text: Binding<String>,
        prompt: String,
        measuredSize: Binding<CGSize>,
        fontSize: Binding<CGFloat>,
        shrinkThresholdSize: CGSize,
        isFocused: Binding<Bool>
    ) -> some View {
        let minEditorWidth: CGFloat = 140
        let minEditorHeight: CGFloat = 76
        let contentSize = measuredSize.wrappedValue
        let editorWidth = max(shrinkThresholdSize.width, minEditorWidth)
        let editorHeight = min(max(contentSize.height, minEditorHeight), shrinkThresholdSize.height)

        return ZStack(alignment: .center) {
            if text.wrappedValue.isEmpty {
                Text(prompt)
                    .font(.system(size: fontSize.wrappedValue, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.28))
                    .multilineTextAlignment(.center)
            }

            CenteredGrowingTextView(
                text: text,
                isFocused: isFocused,
                measuredSize: measuredSize,
                fontSize: fontSize,
                shrinkThresholdSize: shrinkThresholdSize,
                sideLabel: isFlipped ? "Back" : "Front",
                isSaveEnabled: saveButtonEnabled,
                onCancel: cancelEditing,
                onFlip: toggleFlip,
                onSave: saveEditing
            )
            .frame(width: editorWidth, height: editorHeight)
            .opacity(text.wrappedValue.isEmpty ? 0.14 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cyan.opacity(0.14))
        )
        .frame(width: editorWidth + 28, height: editorHeight + 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var editControls: some View {
        Group {
            if isEditing {
                editingToolbarControls
            } else {
                bottomToolbar
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .animation(.spring(response: 0.22, dampingFraction: 0.9), value: isEditing)
        .onPreferenceChange(AddButtonFramePreferenceKey.self) { frame in
            addButtonFrame = frame
        }
        .onPreferenceChange(TrashButtonFramePreferenceKey.self) { frame in
            trashButtonFrame = frame
        }
        .alert(
            "Delete this card?",
            isPresented: $isDeleteConfirmationPresented,
        ) {
            Button("Delete Card", role: .destructive) {
                deleteCurrentCard()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var bottomToolbar: some View {
        HStack {
            Button {
                enterFocusMode()
            } label: {
                Image(systemName: "eye.slash")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: toolbarControlSize, height: toolbarControlSize)
            }
            .frame(width: toolbarControlSize, height: toolbarControlSize)
            .buttonStyle(.plain)
            .glassEffect(
                .regular.tint(.clear).interactive(),
                in: Circle()
            )

            Spacer(minLength: 24)

            HStack(spacing: 0) {
                toolbarIconButton(systemName: "trash", isEnabled: viewModel.currentCard != nil) {
                    isDeleteConfirmationPresented = true
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: TrashButtonFramePreferenceKey.self,
                                value: proxy.frame(in: .named("reviewSpace"))
                            )
                    }
                )

                toolbarIconButton(systemName: "pencil", isEnabled: viewModel.currentCard != nil) {
                    enterEditMode()
                }

                toolbarIconButton(systemName: "plus") {
                    beginAddCardFlow()
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: AddButtonFramePreferenceKey.self,
                                value: proxy.frame(in: .named("reviewSpace"))
                            )
                    }
                )
            }
            .frame(height: toolbarControlSize)
            .padding(.horizontal, 4)
            .glassEffect(
                .regular.tint(.clear).interactive(),
                in: .rect(cornerRadius: toolbarControlSize / 2)
            )
        }
    }

    private var editingToolbarControls: some View {
        GlassEffectContainer(spacing: controlButtonSpacing) {
            HStack(spacing: controlButtonSpacing) {
                Button {
                    cancelEditing()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
                .frame(width: 44, height: 44)
                .buttonBorderShape(.circle)
                .buttonStyle(.glass(.clear))
                .glassEffectID(isAddingNewCard ? "add-cancel" : "edit-cancel", in: editControlsNamespace)
                .glassEffectTransition(.matchedGeometry)

                saveToolbarButton
            }
            .frame(height: 44)
        }
    }

    private var keyboardAccessoryLabel: some View {
        Text(isFlipped ? "Back" : "Front")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .glassEffect(.regular.tint(.clear), in: .capsule)
    }

    private var keyboardAccessoryControlBand: some View {
        HStack(spacing: 0) {
            keyboardAccessoryButton(systemName: "xmark") {
                cancelEditing()
            }

            keyboardAccessoryButton(systemName: "rectangle.portrait.rotate") {
                toggleFlip()
            }

            keyboardSaveButton
        }
        .frame(height: toolbarControlSize)
        .padding(.horizontal, 4)
        .glassEffect(
            .regular.tint(.clear).interactive(),
            in: .rect(cornerRadius: toolbarControlSize / 2)
        )
    }

    private func keyboardAccessoryButton(
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: toolbarControlSize, height: toolbarControlSize)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var keyboardSaveButton: some View {
        if saveButtonEnabled {
            Button {
                saveEditing()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: toolbarControlSize, height: toolbarControlSize)
            }
            .background(Color.blue.opacity(0.9), in: Circle())
            .buttonStyle(.plain)
        } else {
            Button {
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.45))
                    .frame(width: toolbarControlSize, height: toolbarControlSize)
            }
            .disabled(true)
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var saveToolbarButton: some View {
        if saveButtonEnabled {
            Button {
                saveEditing()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .frame(width: 44, height: 44)
            .tint(.blue)
            .buttonBorderShape(.circle)
            .buttonStyle(.glassProminent)
            .glassEffectID(isAddingNewCard ? "add-main" : "edit-main", in: editControlsNamespace)
            .glassEffectTransition(.matchedGeometry)
        } else {
            Button {
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.45))
                    .frame(width: 44, height: 44)
            }
            .disabled(true)
            .frame(width: 44, height: 44)
            .buttonBorderShape(.circle)
            .buttonStyle(.glass(.clear))
            .glassEffectID(isAddingNewCard ? "add-main" : "edit-main", in: editControlsNamespace)
            .glassEffectTransition(.matchedGeometry)
        }
    }

    private func toolbarIconButton(
        systemName: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary.opacity(isEnabled ? 1 : 0.35))
                .frame(width: toolbarControlSize, height: toolbarControlSize)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }

    private func enterEditMode() {
        guard let item = viewModel.currentCard?.item else { return }
        isAddingNewCard = false
        draftCard = nil
        loadDrafts(from: item)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isEditing = true
        }
        translation = .zero
        resetPressInteraction()
        isCommittingSwipe = false
        touchMoved = false
        focusVisibleEditor(after: 0.01)
    }

    private func cancelEditing() {
        if isAddingNewCard {
            discardDraftCard()
            return
        }

        if let item = viewModel.currentCard?.item {
            loadDrafts(from: item)
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isEditing = false
        }
        runCancelShake()
        dismissEditorKeyboard()
    }

    private func saveEditing() {
        let trimmedGreek = draftFrontText.trimmingCharacters(in: .whitespacesAndNewlines)
        let englishLines = normalizedLines(from: draftEnglishText)
        let germanLines = normalizedLines(from: draftGermanText)

        guard saveButtonEnabled else { return }

        if isAddingNewCard {
            viewModel.addNewCard(
                greek: trimmedGreek,
                english: englishLines,
                german: germanLines
            )
            draftCard = nil
            isAddingNewCard = false
        } else {
            viewModel.updateCurrentCard(
                greek: trimmedGreek,
                english: englishLines,
                german: germanLines
            )
        }

        runSaveGlow()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isEditing = false
        }
        dismissEditorKeyboard()
    }

    private func loadDrafts(from item: VocabItem) {
        draftFrontText = item.greek
        draftEnglishText = item.english.joined(separator: "\n")
        draftGermanText = item.german.joined(separator: "\n")
    }

    private func clearDrafts() {
        draftFrontText = ""
        draftEnglishText = ""
        draftGermanText = ""
    }

    private func deleteCurrentCard() {
        guard viewModel.currentCard != nil, !isEditing else { return }
        let targetOffset = deleteDepartureOffset()

        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            departureOffset = targetOffset
            departureScale = 0.18
            departureOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            viewModel.deleteCurrentCard()
        }
    }

    private func deleteDepartureOffset() -> CGSize {
        guard !cardFrame.isEmpty, !trashButtonFrame.isEmpty else {
            return CGSize(width: 180, height: 220)
        }

        let horizontalDelta = trashButtonFrame.midX - cardFrame.midX
        let verticalDelta = trashButtonFrame.midY - cardFrame.midY
        return CGSize(
            width: horizontalDelta * 1.35,
            height: verticalDelta * 1.35
        )
    }

    private func beginAddCardFlow() {
        guard !isEditing else { return }

        translation = .zero
        resetPressInteraction()
        isCommittingSwipe = false
        touchMoved = false

        withAnimation(.easeIn(duration: 0.14)) {
            departureOffset = CGSize(width: 0, height: -42)
            departureScale = 0.95
            departureOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            draftCard = VocabCardState(
                item: VocabItem(
                    id: "draft.new-card",
                    greek: "",
                    lemma: nil,
                    partOfSpeech: nil,
                    translations: [
                        "en": [],
                        "de": []
                    ]
                ),
                progress: .initial
            )
            isAddingNewCard = true
            clearDrafts()
            prepareDraftCardFromAddButton()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isEditing = true
            }
            focusVisibleEditor(after: 0.01)
        }
    }

    private func prepareDraftCardFromAddButton() {
        entrySourceFrameOverride = addButtonFrame.isEmpty ? nil : addButtonFrame
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            departureOffset = .zero
            departureScale = 1
            departureOpacity = 1
            isFlipped = false
            entryOffset = .zero
            entryScale = 1
            randomizeCardTilts()
        }
    }

    private func discardDraftCard() {
        draftCard = nil
        isAddingNewCard = false
        dismissEditorKeyboard()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isEditing = false
        }
        runCancelShake()
        resetPresentedCardState()
    }

    private func resetPresentedCardState() {
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true

        withTransaction(resetTransaction) {
            isFlipped = false
            translation = .zero
            isCommittingSwipe = false
            if !isAddingNewCard {
                isEditing = false
            }
            entryOffset = .zero
            entryScale = 1
            departureOffset = .zero
            departureScale = 1
            departureOpacity = 1
            randomizeCardTilts()
            resetPressInteraction()
        }

        if viewModel.currentCard == nil {
            isFocusMode = false
        }

        if let item = presentedCard?.item {
            loadDrafts(from: item)
        }
        scheduleEntryAnimation()
    }

    private func preparePresentedCard(using item: VocabItem) {
        randomizeCardTilts()
        loadDrafts(from: item)
        scheduleEntryAnimation()
    }

    private func normalizedLines(from text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func toggleFlip() {
        if isFlipped {
            frontFlipAxisTiltDegrees = Double.random(in: -2 ... 2)
            activeFlipAxisTiltDegrees = frontFlipAxisTiltDegrees
        } else {
            backFlipAxisTiltDegrees = Double.random(in: -2 ... 2)
            activeFlipAxisTiltDegrees = backFlipAxisTiltDegrees
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            isFlipped.toggle()
        }

        if isEditing {
            isEditorFocused = true
        }
    }

    private func focusVisibleEditor(after delay: TimeInterval = 0.01) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isEditing else { return }
            isEditorFocused = true
        }
    }

    private func dismissEditorKeyboard() {
        isEditorFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func updatePressInteraction(with value: DragGesture.Value, cardSize: CGSize) {
        let safeWidth = max(cardSize.width, 1)
        let safeHeight = max(cardSize.height, 1)
        let normalizedX = min(max(value.startLocation.x / safeWidth, 0), 1)
        let normalizedY = min(max(value.startLocation.y / safeHeight, 0), 1)

        let touchAnchor = UnitPoint(x: normalizedX, y: normalizedY)
        let counterAnchor = UnitPoint(x: 1 - normalizedX, y: 1 - normalizedY)
        pressShrinkAnchor = touchAnchor
        pressTiltAnchor = counterAnchor

        let radialDistance = hypot(value.translation.width, value.translation.height)
        let depth = min(1, radialDistance / 35 + 0.55)
        pressShrinkScale = 1 - (0.01 * depth)

        let relativeX = normalizedX - 0.5
        let relativeY = normalizedY - 0.5
        pressTiltXDegrees = Double(-relativeY * (6.4 / 3) * depth)
        pressTiltYDegrees = Double(relativeX * (6.4 / 3) * depth)
    }

    private func resetPressInteraction(animated: Bool = false) {
        if animated {
            withAnimation(.easeOut(duration: 0.16)) {
                pressShrinkScale = 1
                pressTiltXDegrees = 0
                pressTiltYDegrees = 0
            }
        } else {
            pressShrinkScale = 1
            pressTiltXDegrees = 0
            pressTiltYDegrees = 0
        }
        pressShrinkAnchor = .center
        pressTiltAnchor = .center
    }

    private func animateEditTransition(editing: Bool) {
        withAnimation(.easeInOut(duration: 0.24)) {
            editTransitionScale = 1
        }
    }

    private func runCancelShake() {
        cancelShakeDegrees = 0

        let sequence: [(TimeInterval, Double)] = [
            (0.00, -7),
            (0.06, 7),
            (0.12, -5),
            (0.18, 5),
            (0.24, 0)
        ]

        for (delay, angle) in sequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if angle != 0 {
                    triggerShakeHaptic()
                }
                withAnimation(.easeInOut(duration: 0.06)) {
                    cancelShakeDegrees = angle
                }
            }
        }
    }

    private func runSaveGlow() {
        saveGlowScale = 0.98
        saveGlowOpacity = 0
        saveGlowBlur = 8

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            triggerSaveBurstHaptic()
            saveGlowScale = 0.985
            saveGlowOpacity = 0.96
            saveGlowBlur = 9

            withAnimation(.easeOut(duration: 0.22)) {
                saveGlowScale = 1.14
                saveGlowOpacity = 0
                saveGlowBlur = 32
            }
        }
    }

    private func triggerShakeHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.55)
    }

    private func triggerSaveBurstHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }

    private func triggerStackPulseHaptic(for stack: LearningStack) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        let intensity: CGFloat

        switch stack {
        case .new, .seen:
            style = .soft
            intensity = 0.42
        case .once, .solid:
            style = .light
            intensity = 0.58
        case .good:
            style = .medium
            intensity = 0.72
        case .know:
            style = .rigid
            intensity = 0.82
        }

        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }

    private func runStackTransferAnimation(_ transfer: StackTransferEvent) {
        transferSourceStack = transfer.from
        transferDestinationStack = transfer.to
        transferSourcePulse = 0
        transferDestinationPulse = 0
        triggerStackPulseHaptic(for: transfer.from)

        withAnimation(.spring(response: 0.18, dampingFraction: 0.72)) {
            transferSourcePulse = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                transferSourcePulse = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            triggerStackPulseHaptic(for: transfer.to)
            withAnimation(.spring(response: 0.22, dampingFraction: 0.68)) {
                transferDestinationPulse = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                transferDestinationPulse = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            if transferSourceStack == transfer.from {
                transferSourceStack = nil
            }
            if transferDestinationStack == transfer.to {
                transferDestinationStack = nil
            }
        }
    }

    private func randomizeCardTilts() {
        frontFlipAxisTiltDegrees = Double.random(in: -2 ... 2)
        backFlipAxisTiltDegrees = Double.random(in: -2 ... 2)
        activeFlipAxisTiltDegrees = isFlipped ? backFlipAxisTiltDegrees : frontFlipAxisTiltDegrees
    }

    private func scheduleEntryAnimation(attempt: Int = 0) {
        guard let currentCard = presentedCard else { return }

        DispatchQueue.main.async {
            guard !cardFrame.isEmpty else {
                if attempt < 20 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scheduleEntryAnimation(attempt: attempt + 1)
                    }
                }
                return
            }

            let sourceFrame: CGRect?
            if let entrySourceFrameOverride {
                sourceFrame = entrySourceFrameOverride
            } else {
                sourceFrame = stackFrames[currentCard.progress.stack]
            }

            guard let sourceFrame else {
                if attempt < 20 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scheduleEntryAnimation(attempt: attempt + 1)
                    }
                }
                return
            }

            let horizontalDelta = sourceFrame.midX - cardFrame.midX
            let verticalDelta = sourceFrame.midY - cardFrame.midY
            let widthScale = sourceFrame.width / cardFrame.width
            let heightScale = sourceFrame.height / cardFrame.height
            let startScale = max(0.08, min(widthScale, heightScale))

            var startTransaction = Transaction()
            startTransaction.disablesAnimations = true
            withTransaction(startTransaction) {
                entryOffset = CGSize(
                    width: horizontalDelta,
                    height: verticalDelta
                )
                entryScale = startScale
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.easeInOut(duration: 2.4)) {
                    entryOffset = .zero
                    entryScale = 1
                }
                entrySourceFrameOverride = nil
            }
        }
    }

    private var reviewBackgroundColor: Color {
        if translation.width > 20 {
            let strength = min(translation.width / 180, 1)
            return Color(red: 0.84 - 0.22 * strength, green: 0.93, blue: 0.84 - 0.22 * strength)
        }
        if translation.width < -20 {
            let strength = min(abs(translation.width) / 180, 1)
            return Color(red: 0.97, green: 0.89 - 0.25 * strength, blue: 0.9 - 0.2 * strength)
        }
        return Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    private func backText(for item: VocabItem) -> String {
        item.english.first ?? "-"
    }

    private func cardFaceText(_ text: String) -> some View {
        AdaptiveCardText(text: text)
            .padding(.horizontal, 20)
    }

    private func cardBackFaceText(_ text: String) -> some View {
        cardFaceText(text)
            .modifier(BackFaceTilt())
    }

    private func pillColor(_ stack: LearningStack) -> Color {
        switch stack {
        case .new: return .purple
        case .seen: return .red
        case .once: return .orange
        case .solid: return .yellow
        case .good: return .green
        case .know: return .blue
        }
    }
}

private struct StackFramePreferenceKey: PreferenceKey {
    static var defaultValue: [LearningStack: CGRect] = [:]

    static func reduce(value: inout [LearningStack: CGRect], nextValue: () -> [LearningStack: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct CardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct AddButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct TrashButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct BackFaceTilt: ViewModifier {
    func body(content: Content) -> some View {
        content.rotation3DEffect(
            .degrees(180),
            axis: (x: 0, y: 1, z: 0)
        )
    }
}

private struct AdaptiveCardText: View {
    let text: String

    private let maximumFontSize: CGFloat = 42
    private let minimumFontSize: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let limitSize = CGSize(
                width: proxy.size.width * 0.75,
                height: proxy.size.height * 0.75
            )
            let fontSize = fittingFontSize(for: text, in: limitSize)

            Text(text)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)
                .frame(width: limitSize.width, height: limitSize.height, alignment: .center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func fittingFontSize(for text: String, in size: CGSize) -> CGFloat {
        let measuredText = text.isEmpty ? " " : text
        var low = minimumFontSize
        var high = maximumFontSize

        for _ in 0..<8 {
            let mid = (low + high) / 2
            if measuredSize(for: measuredText, fontSize: mid, constrainedWidth: size.width).fits(in: size) {
                low = mid
            } else {
                high = mid
            }
        }

        return low
    }

    private func measuredSize(for text: String, fontSize: CGFloat, constrainedWidth: CGFloat) -> CGSize {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let rect = (text as NSString).boundingRect(
            with: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .paragraphStyle: paragraph
            ],
            context: nil
        )

        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }
}

private extension CGSize {
    func fits(in limit: CGSize) -> Bool {
        width <= limit.width && height <= limit.height
    }
}

private struct CardMotionModifier: ViewModifier {
    let entryScale: CGFloat
    let editTransitionScale: CGFloat
    let pressShrinkScale: CGFloat
    let pressShrinkAnchor: UnitPoint
    let dragRollDegrees: Double
    let cancelShakeDegrees: Double
    let pressTiltXDegrees: Double
    let pressTiltYDegrees: Double
    let pressTiltAnchor: UnitPoint
    let flipRotation: Double
    let flipAxis: (x: CGFloat, y: CGFloat, z: CGFloat)
    let translation: CGSize
    let entryOffset: CGSize
    let isEditing: Bool

    func body(content: Content) -> some View {
        let activeEntryScale = isEditing ? 1 : entryScale
        let activePressShrinkScale = isEditing ? 1 : pressShrinkScale
        let activeDragRollDegrees = isEditing ? 0 : dragRollDegrees
        let activePressTiltXDegrees = isEditing ? 0 : pressTiltXDegrees
        let activePressTiltYDegrees = isEditing ? 0 : pressTiltYDegrees
        let activeFlipRotation = isEditing ? 0 : flipRotation
        let activeTranslation = isEditing ? .zero : translation
        let activeEntryOffset = isEditing ? .zero : entryOffset

        content
            .scaleEffect(activeEntryScale, anchor: .center)
            .scaleEffect(editTransitionScale, anchor: .center)
            .scaleEffect(activePressShrinkScale, anchor: pressShrinkAnchor)
            .rotationEffect(.degrees(activeDragRollDegrees + cancelShakeDegrees))
            .rotation3DEffect(
                .degrees(activePressTiltXDegrees),
                axis: (x: 1, y: 0, z: 0),
                anchor: pressTiltAnchor,
                perspective: 0.9
            )
            .rotation3DEffect(
                .degrees(activePressTiltYDegrees),
                axis: (x: 0, y: 1, z: 0),
                anchor: pressTiltAnchor,
                perspective: 0.9
            )
            .rotation3DEffect(
                .degrees(activeFlipRotation),
                axis: flipAxis,
                perspective: 0.9
            )
            .offset(
                x: activeTranslation.width + activeEntryOffset.width,
                y: activeTranslation.height * 0.2 + activeEntryOffset.height
            )
    }
}

private struct KeyboardAccessoryContent: View {
    let sideLabel: String
    let isSaveEnabled: Bool
    let onCancel: () -> Void
    let onFlip: () -> Void
    let onSave: () -> Void

    private let controlSize: CGFloat = 48

    var body: some View {
        HStack(spacing: 16) {
            Text(sideLabel)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .glassEffect(.regular.tint(.clear), in: .capsule)

            Spacer(minLength: 24)

            HStack(spacing: 0) {
                accessoryButton(systemName: "xmark", action: onCancel)
                accessoryButton(systemName: "rectangle.portrait.rotate", action: onFlip)

                Button(action: onSave) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSaveEnabled ? .blue : .primary.opacity(0.45))
                        .frame(width: controlSize, height: controlSize)
                }
                .disabled(!isSaveEnabled)
                .buttonStyle(.plain)
            }
            .frame(height: controlSize)
            .padding(.horizontal, 4)
            .glassEffect(
                .regular.tint(.clear).interactive(),
                in: .rect(cornerRadius: controlSize / 2)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(height: 56)
        .background(Color.clear)
    }

    private func accessoryButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: controlSize, height: controlSize)
        }
        .buttonStyle(.plain)
    }
}

private struct CenteredGrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var measuredSize: CGSize
    @Binding var fontSize: CGFloat
    let shrinkThresholdSize: CGSize
    let sideLabel: String
    let isSaveEnabled: Bool
    let onCancel: () -> Void
    let onFlip: () -> Void
    let onSave: () -> Void

    private var editorFont: UIFont {
        UIFont.systemFont(ofSize: fontSize, weight: .semibold)
    }

    func makeUIView(context: Context) -> WideCaretTextView {
        let textView = WideCaretTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textColor = .black
        textView.font = editorFont
        textView.textAlignment = .center
        textView.tintColor = UIColor.systemCyan
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        context.coordinator.applyCenteredTypingAttributes(to: textView)
        context.coordinator.updateAccessory(for: textView, parent: self)
        return textView
    }

    func updateUIView(_ uiView: WideCaretTextView, context: Context) {
        context.coordinator.updateAccessory(for: uiView, parent: self)

        if uiView.text != text {
            uiView.text = text
        }
        if uiView.font?.pointSize != fontSize {
            uiView.font = editorFont
        }
        context.coordinator.applyCenteredTypingAttributes(to: uiView)
        context.coordinator.recalculateSize(
            for: uiView,
            measuredSize: $measuredSize,
            fontSize: $fontSize,
            shrinkThresholdSize: shrinkThresholdSize
        )

        if isFocused, !uiView.isFirstResponder {
            context.coordinator.requestFocus(on: uiView)
        } else if !isFocused, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private var parent: CenteredGrowingTextView
        private var accessoryHost: UIHostingController<KeyboardAccessoryContent>?
        private var accessoryContainer: UIView?

        init(parent: CenteredGrowingTextView) {
            self.parent = parent
        }

        func updateAccessory(for textView: UITextView, parent: CenteredGrowingTextView) {
            self.parent = parent

            let accessoryContent = KeyboardAccessoryContent(
                sideLabel: parent.sideLabel,
                isSaveEnabled: parent.isSaveEnabled,
                onCancel: parent.onCancel,
                onFlip: parent.onFlip,
                onSave: parent.onSave
            )

            if let accessoryHost {
                accessoryHost.rootView = accessoryContent
                if textView.inputAccessoryView !== accessoryContainer {
                    textView.inputAccessoryView = accessoryContainer
                }
                return
            }

            let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 56))
            container.backgroundColor = .clear

            let host = UIHostingController(rootView: accessoryContent)
            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(host.view)

            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: container.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])

            accessoryHost = host
            accessoryContainer = container
            textView.inputAccessoryView = container
        }

        func requestFocus(on textView: UITextView) {
            guard !textView.isFirstResponder else { return }
            requestFocus(on: textView, attempt: 0)
        }

        private func requestFocus(on textView: UITextView, attempt: Int) {
            guard parent.isFocused, !textView.isFirstResponder else { return }

            if textView.window != nil, textView.becomeFirstResponder() {
                textView.reloadInputViews()
                return
            }

            guard attempt < 8 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.requestFocus(on: textView, attempt: attempt + 1)
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isFocused {
                parent.isFocused = true
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isFocused {
                parent.isFocused = false
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            if parent.text != textView.text {
                parent.text = textView.text
            }
            applyCenteredTypingAttributes(to: textView)
            recalculateSize(
                for: textView,
                measuredSize: parent.$measuredSize,
                fontSize: parent.$fontSize,
                shrinkThresholdSize: parent.shrinkThresholdSize
            )
        }

        func applyCenteredTypingAttributes(to textView: UITextView) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            textView.typingAttributes = [
                .font: parent.editorFont,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]
        }

        func recalculateSize(
            for textView: UITextView,
            measuredSize: Binding<CGSize>,
            fontSize: Binding<CGFloat>,
            shrinkThresholdSize: CGSize
        ) {
            let constrainedWidth = max(shrinkThresholdSize.width, 1)
            let constrainedHeight = max(shrinkThresholdSize.height, 1)
            let text = textView.text.isEmpty ? " " : textView.text ?? " "
            let baseFont = UIFont.systemFont(ofSize: 42, weight: .semibold)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byWordWrapping

            let baseHeight = measuredTextHeight(
                text,
                font: baseFont,
                paragraphStyle: paragraph,
                constrainedWidth: constrainedWidth
            )
            let heightScale = constrainedHeight / max(baseHeight, 1)
            let proposedScale = min(1, heightScale)
            let clampedFontSize = max(24, min(42, 42 * proposedScale))
            let displayFont = UIFont.systemFont(ofSize: clampedFontSize, weight: .semibold)
            let displayHeight = measuredTextHeight(
                text,
                font: displayFont,
                paragraphStyle: paragraph,
                constrainedWidth: constrainedWidth
            )
            let size = CGSize(width: constrainedWidth, height: min(displayHeight, constrainedHeight))

            if abs(fontSize.wrappedValue - clampedFontSize) > 0.1 {
                DispatchQueue.main.async {
                    fontSize.wrappedValue = clampedFontSize
                }
            }

            if abs(measuredSize.wrappedValue.width - size.width) > 1
                || abs(measuredSize.wrappedValue.height - size.height) > 1 {
                DispatchQueue.main.async {
                    measuredSize.wrappedValue = size
                }
            }
        }

        private func measuredTextHeight(
            _ text: String,
            font: UIFont,
            paragraphStyle: NSParagraphStyle,
            constrainedWidth: CGFloat
        ) -> CGFloat {
            let rect = (text as NSString).boundingRect(
                with: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [
                    .font: font,
                    .paragraphStyle: paragraphStyle
                ],
                context: nil
            )
            return ceil(rect.height)
        }
    }
}

private final class WideCaretTextView: UITextView {
    override func caretRect(for position: UITextPosition) -> CGRect {
        var rect = super.caretRect(for: position)
        rect.size.width = max(rect.size.width * 3, 6)
        return rect
    }
}

#Preview {
    ContentView()
}

private struct StatPill: View {
    let title: String
    let count: Int
    let color: Color
    let inwardPulse: CGFloat
    let outwardPulse: CGFloat

    var body: some View {
        let sourceScale = 1 - (0.12 * inwardPulse)
        let destinationScale = 1 + (0.14 * outwardPulse)

        VStack(spacing: 4) {
            Text(shortNumber(count))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color.opacity(0.9))
                .frame(width: 52, height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.25))
                        .scaleEffect(
                            x: sourceScale * destinationScale,
                            y: sourceScale * destinationScale,
                            anchor: .center
                        )
                }
                .scaleEffect(
                    x: (1 - (0.04 * inwardPulse)) * (1 + (0.05 * outwardPulse)),
                    y: (1 - (0.04 * inwardPulse)) * (1 + (0.05 * outwardPulse)),
                    anchor: .center
                )

            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func shortNumber(_ value: Int) -> String {
        if value >= 1000 {
            let compact = Double(value) / 1000
            return String(format: compact >= 10 ? "%.0fk" : "%.1fk", compact)
        }
        return "\(value)"
    }
}
