//
//  ReviewView.swift
//  learn-greek
//
//  Created by Leonidas von Bothmer on 30.04.26.
//

import SwiftUI
import UIKit

struct ReviewView: View {
    @StateObject private var viewModel = ReviewSessionModel()
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
        ReviewStackSummary(
            countsByStack: viewModel.countsByStack,
            transferSourceStack: transferSourceStack,
            transferDestinationStack: transferDestinationStack,
            transferSourcePulse: transferSourcePulse,
            transferDestinationPulse: transferDestinationPulse
        )
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
        ReviewCardSurface(
            item: card.item,
            isEditing: isEditing,
            isFlipped: isFlipped,
            saveGlowColor: saveGlowColor,
            saveGlowScale: saveGlowScale,
            saveGlowOpacity: saveGlowOpacity,
            saveGlowBlur: saveGlowBlur,
            isSaveEnabled: saveButtonEnabled,
            draftFrontText: $draftFrontText,
            draftEnglishText: $draftEnglishText,
            frontEditorSize: $frontEditorSize,
            backEditorSize: $backEditorSize,
            frontEditorFontSize: $frontEditorFontSize,
            backEditorFontSize: $backEditorFontSize,
            isEditorFocused: $isEditorFocused,
            onCancel: cancelEditing,
            onFlip: toggleFlip,
            onSave: saveEditing
        )
    }

    private var editControls: some View {
        ReviewToolbar(
            isEditing: isEditing,
            hasCurrentCard: viewModel.currentCard != nil,
            isAddingNewCard: isAddingNewCard,
            isSaveEnabled: saveButtonEnabled,
            namespace: editControlsNamespace,
            onFocus: enterFocusMode,
            onDelete: {
                isDeleteConfirmationPresented = true
            },
            onEdit: enterEditMode,
            onAdd: beginAddCardFlow,
            onCancel: cancelEditing,
            onSave: saveEditing
        )
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

}

#Preview {
    ReviewView()
}
