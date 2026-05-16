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
    @State private var isStreakFireEnabled = true
    @AppStorage("review.showBackFirst") private var isBackSideFirst = false
    @State private var isFocusDisclaimerVisible = true
    @State private var focusDisclaimerHideTask: Task<Void, Never>?
    @State private var translation: CGSize = .zero
    @State private var isFlipped = false
    @State private var isBackFaceVisible = false
    @State private var touchMoved = false
    @State private var isCommittingSwipe = false
    @State private var isEditing = false
    @State private var isEditViewPresented = false
    @State private var isBatchAdding = false
    @State private var isDeleteConfirmationPresented = false
    @State private var draftFrontText = ""
    @State private var draftBackText = ""
    @State private var draftCard: ReviewCardState?
    @State private var isAddingNewCard = false
    @State private var isEditKeyboardFocusRequested = false
    @State private var editCloseTask: Task<Void, Never>?
    @State private var editReservedKeyboardHeight: CGFloat = 0
    @State private var lastObservedKeyboardHeight: CGFloat = 0
    @State private var observedScreenHeight: CGFloat = 0
    @State private var frontFlipAxisTiltDegrees = Double.random(in: -2 ... 2)
    @State private var backFlipAxisTiltDegrees = Double.random(in: -2 ... 2)
    @State private var activeFlipAxisTiltDegrees = Double.random(in: -2 ... 2)
    @State private var stackFrames: [LearningStack: CGRect] = [:]
    @State private var reviewViewportSize: CGSize = .zero
    @State private var cardFrame: CGRect = .zero
    @State private var addButtonFrame: CGRect = .zero
    @State private var trashButtonFrame: CGRect = .zero
    @State private var entrySourceFrameOverride: CGRect?
    @State private var entryOffset: CGSize = .zero
    @State private var entryScale: CGFloat = 1
    @State private var departureOffset: CGSize = .zero
    @State private var departureScale: CGFloat = 1
    @State private var departureOpacity: Double = 1
    @State private var pressShrinkScale: CGFloat = 1
    @State private var pressShrinkAnchor: UnitPoint = .center
    @State private var pressTiltAnchor: UnitPoint = .center
    @State private var pressTiltXDegrees: Double = 0
    @State private var pressTiltYDegrees: Double = 0
    @State private var dropTargetStack: LearningStack?
    @State private var lastDropTargetStack: LearningStack?
    @State private var cancelShakeDegrees: Double = 0
    @State private var saveGlowScale: CGFloat = 0.96
    @State private var saveGlowOpacity: Double = 0
    @State private var saveGlowBlur: CGFloat = 10
    @State private var transferSourceStack: LearningStack?
    @State private var transferDestinationStack: LearningStack?
    @State private var transferSourcePulse: CGFloat = 0
    @State private var transferDestinationPulse: CGFloat = 0
    @State private var stackBurstEvent: ReviewStackBurstEvent?
    @State private var streakBreakAnimation: StreakBreakAnimation?
    @State private var isLaunchCardContentVisible = false
    @State private var isLaunchChromeVisible = false
    @State private var isReviewChromeReturnVisible = true

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

    private var isReviewChromeSuppressed: Bool {
        isEditing || isEditViewPresented || isBatchAdding
    }

    private var isReviewChromeVisible: Bool {
        isLaunchChromeVisible && isReviewChromeReturnVisible
    }

    private var dragRollDegrees: Double {
        guard !isReviewChromeSuppressed else { return 0 }
        return Double(translation.width / 14)
    }

    private var chromeInset: CGFloat {
        16
    }

    private var saveGlowColor: Color {
        Color(red: 0.22, green: 0.22, blue: 0.98)
    }

    private var hasPendingEdits: Bool {
        guard let note = presentedCard?.note else { return false }

        let trimmedFront = draftFrontText.trimmingCharacters(in: .whitespacesAndNewlines)
        let backLines = normalizedLines(from: draftBackText)

        return trimmedFront != CardNoteDisplay.frontPlainText(for: note)
            || backLines != CardNoteDisplay.backLines(for: note)
    }

    private var canSaveDraftCard: Bool {
        let trimmedFront = draftFrontText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFront.isEmpty else { return false }
        return !normalizedLines(from: draftBackText).isEmpty
    }

    private var isEditingExistingCard: Bool {
        isEditing && !isAddingNewCard
    }

    private var presentedCard: ReviewCardState? {
        draftCard ?? viewModel.currentCard
    }

    private var saveButtonEnabled: Bool {
        canSaveDraftCard && (isAddingNewCard || hasPendingEdits)
    }

    var body: some View {
        ZStack {
            if isFocusMode {
                ReviewStreakSunriseBackground(
                    correctStreak: 0,
                    breakAnimation: nil,
                    translation: translation
                )
            } else {
                ReviewStreakSunriseBackground(
                    correctStreak: isStreakFireEnabled ? viewModel.correctSwipeStreak : 0,
                    breakAnimation: isStreakFireEnabled ? streakBreakAnimation : nil,
                    translation: translation
                )
            }

            GeometryReader { proxy in
                let metrics = cardMetrics(for: proxy)
                let manualKeyboardReserve = editManualKeyboardReserve(for: proxy)

                ZStack {
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
                            alignment: .center
                        )
                        .padding(.bottom, manualKeyboardReserve)
                        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: manualKeyboardReserve)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !isFocusMode && !isReviewChromeSuppressed {
                        stackSummaryRow
                            .padding(.top, chromeInset)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(isReviewChromeVisible ? 1 : 0.38, anchor: .top)
                            .offset(y: isReviewChromeVisible ? 0 : -86)
                            .opacity(isReviewChromeVisible ? 1 : 0)
                            .animation(.spring(response: 0.52, dampingFraction: 0.62), value: isReviewChromeVisible)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !isFocusMode && !isReviewChromeSuppressed {
                        editControls
                            .padding(.horizontal, 36)
                            .padding(.bottom, 0)
                            .offset(y: isReviewChromeVisible ? 0 : 92)
                            .opacity(isReviewChromeVisible ? 1 : 0)
                            .animation(.spring(response: 0.48, dampingFraction: 0.78), value: isReviewChromeVisible)
                    }
                }
                .overlay(alignment: .bottom) {
                    if isFocusMode && isFocusDisclaimerVisible {
                        focusModeDisclaimerBar
                            .padding(.bottom, chromeInset)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if isEditViewPresented && isEditKeyboardFocusRequested {
                        editAccessoryControls
                            .padding(.trailing, 36)
                            .padding(.bottom, 8)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let stackBurstEvent {
                        ReviewStackCompletionBurst(event: stackBurstEvent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                }
                .coordinateSpace(name: "reviewSpace")
                .onAppear {
                    reviewViewportSize = proxy.size
                }
                .onChange(of: proxy.size) { _, size in
                    reviewViewportSize = size
                }
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
                .onChange(of: viewModel.streakBreakEvent) { _, event in
                    guard let event else { return }
                    runStreakBreakAnimation(event)
                }
                .task {
                    await runLaunchIntro()
                }
                .task {
                    await observeKeyboardHeight()
                }
            }
        }
        .onChange(of: isBackSideFirst) { _, _ in
            resetPresentedCardState()
        }
        .sheet(isPresented: $isBatchAdding, onDismiss: { dismissKeyboardFromWindows() }) {
            BatchAddCardsView(
                onCancel: { isBatchAdding = false },
                onSave: { completedRows in
                    let notes = completedRows.map { row in
                        CardNote(
                            id: "custom.\(UUID().uuidString)",
                            cardType: .genericV1,
                            facets: [
                                CardFacetKey.front: [row.front],
                                CardFacetKey.back: [row.back]
                            ]
                        )
                    }
                    viewModel.addNotes(notes)
                    isBatchAdding = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func dismissKeyboardFromWindows() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.windows.forEach { $0.endEditing(true) }
        }
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    @MainActor
    private func runLaunchIntro() async {
        guard !isLaunchCardContentVisible || !isLaunchChromeVisible else { return }

        try? await Task.sleep(for: .seconds(1.08))
        withAnimation(.easeOut(duration: 0.11)) {
            isLaunchCardContentVisible = true
        }

        try? await Task.sleep(for: .seconds(0.1))
        withAnimation(.spring(response: 0.52, dampingFraction: 0.66)) {
            isLaunchChromeVisible = true
        }
    }

    @MainActor
    private func observeKeyboardHeight() async {
        for await notification in NotificationCenter.default.notifications(named: UIResponder.keyboardWillChangeFrameNotification) {
            guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                continue
            }

            let screenHeight = endFrame.maxY
            observedScreenHeight = screenHeight
            let keyboardHeight = max(0, screenHeight - endFrame.minY)

            if keyboardHeight > 0 {
                lastObservedKeyboardHeight = keyboardHeight
                withAnimation(.easeOut(duration: 0.22)) {
                    editReservedKeyboardHeight = isEditing ? keyboardHeight : 0
                }
            } else if !isEditing {
                editReservedKeyboardHeight = 0
            }
        }
    }

    private var stackSummaryRow: some View {
        ReviewStackSummary(
            countsByStack: viewModel.countsByStack,
            transferSourceStack: transferSourceStack,
            transferDestinationStack: transferDestinationStack,
            transferSourcePulse: transferSourcePulse,
            transferDestinationPulse: transferDestinationPulse,
            dropTargetStack: dropTargetStack,
            currentStack: viewModel.currentCard?.progress.stack,
            lockedStack: viewModel.lockedStack,
            onStackTap: handleStackTap,
            onStackLongPress: lockStack
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

    private func presentedCardView(for card: ReviewCardState, metrics: CardMetrics) -> some View {
        cardView(for: card, cardSize: metrics.activeSize)
            .frame(width: metrics.activeWidth, height: metrics.activeHeight)
            .background(cardFrameReader)
            .scaleEffect(departureScale)
            .opacity(departureOpacity)
            .offset(
                x: departureOffset.width,
                y: departureOffset.height
            )
            .modifier(CardMotionModifier(
                entryScale: entryScale,
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
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isEditing)
            .animation(.spring(response: 0.5, dampingFraction: 0.84), value: entryOffset)
            .animation(.spring(response: 0.5, dampingFraction: 0.84), value: entryScale)
            .onChange(of: viewModel.cardPresentationID) { _, _ in
                if !isAddingNewCard {
                    resetPresentedCardState()
                }
            }
            .onAppear {
                preparePresentedCard(using: card.note)
            }
    }

    private var cardFrameReader: some View {
        GeometryReader { cardProxy in
            Color.clear
                .preference(
                    key: CardFramePreferenceKey.self,
                    value: cardProxy.frame(in: .named("reviewSpace"))
                )
                .preference(
                    key: LaunchCardFramePreferenceKey.self,
                    value: cardProxy.frame(in: .named("launchSpace"))
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
    private func cardView(for card: ReviewCardState, cardSize: CGSize) -> some View {
        if isEditViewPresented {
            ReviewEditView(
                isBackSide: $isFlipped,
                draftFrontText: $draftFrontText,
                draftBackText: $draftBackText,
                isKeyboardFocusRequested: isEditKeyboardFocusRequested,
                isBackFaceVisible: isBackFaceVisible
            )
        } else {
            cardSurface(for: card)
                .opacity(isLaunchCardContentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.22), value: isLaunchCardContentVisible)
                .gesture(dragGesture(cardSize: cardSize))
                .simultaneousGesture(flipTapGesture())
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
        DragGesture(minimumDistance: 8, coordinateSpace: .named("reviewSpace"))
            .onChanged { value in
                guard !isReviewChromeSuppressed else { return }

                updatePressInteraction(with: value, cardSize: cardSize)

                if !isCommittingSwipe {
                    translation = value.translation
                }
                if hypot(value.translation.width, value.translation.height) > 8 {
                    touchMoved = true
                    updateDropTarget(at: value.location)
                }
            }
            .onEnded { value in
                guard !isReviewChromeSuppressed else { return }
                let swipeThreshold: CGFloat = 90
                let releaseLocation = value.location

                resetPressInteraction(animated: true)

                if let target = stack(at: releaseLocation) {
                    finishStackDrop(to: target, releaseLocation: releaseLocation)
                } else if value.translation.width > swipeThreshold {
                    resetDropTarget()
                    commitSwipe(correct: true)
                } else if value.translation.width < -swipeThreshold {
                    resetDropTarget()
                    commitSwipe(correct: false)
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        translation = .zero
                    }
                    resetDropTarget()
                }

                touchMoved = false
            }
    }

    private func flipTapGesture() -> some Gesture {
        TapGesture()
            .onEnded {
                guard !isReviewChromeSuppressed, !isCommittingSwipe else { return }
                resetDropTarget()
                toggleFlip()
            }
    }

    private func updateDropTarget(at location: CGPoint) {
        let target = stack(at: location)
        if target != dropTargetStack {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.84)) {
                dropTargetStack = target
            }
            if let target, target != lastDropTargetStack {
                triggerDropTargetHaptic()
                lastDropTargetStack = target
            }
        }
    }

    private func handleStackTap(_ stack: LearningStack) {
        if viewModel.lockedStack != nil {
            viewModel.unlockStack()
        }

        selectCardFromStack(stack)
    }

    private func lockStack(_ stack: LearningStack) {
        guard !isReviewChromeSuppressed, !isCommittingSwipe, (viewModel.countsByStack[stack] ?? 0) > 0 else { return }
        viewModel.lockStack(stack)
        triggerStackLockHaptic()
        selectCardFromStack(stack, triggersSelectionHaptic: false) {
            viewModel.selectCard(from: stack)
        }
    }

    private func selectCardFromStack(
        _ stack: LearningStack,
        triggersSelectionHaptic: Bool = true,
        selection: @escaping () -> Void
    ) {
        guard !isReviewChromeSuppressed, !isCommittingSwipe, (viewModel.countsByStack[stack] ?? 0) > 0 else { return }
        isCommittingSwipe = true
        resetDropTarget()
        resetPressInteraction(animated: true)
        if triggersSelectionHaptic {
            triggerDropTargetHaptic()
        }

        guard !cardFrame.isEmpty, let stackFrame = stackFrames[stack] else {
            selection()
            return
        }

        withAnimation(.spring(response: 0.2, dampingFraction: 0.86)) {
            translation = .zero
            departureOffset = CGSize(
                width: stackFrame.midX - cardFrame.midX,
                height: stackFrame.midY - cardFrame.midY
            )
            departureScale = max(0.08, min(stackFrame.width / cardFrame.width, stackFrame.height / cardFrame.height))
            departureOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            entrySourceFrameOverride = stackFrame
            selection()
        }
    }

    private func selectCardFromStack(_ stack: LearningStack) {
        selectCardFromStack(stack) {
            viewModel.selectCard(from: stack)
        }
    }

    private func finishStackDrop(to target: LearningStack, releaseLocation: CGPoint) {
        guard !cardFrame.isEmpty else {
            viewModel.moveCurrentCard(to: target)
            resetDropTarget()
            return
        }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            translation = .zero
            departureOffset = CGSize(
                width: releaseLocation.x - cardFrame.midX,
                height: releaseLocation.y - cardFrame.midY
            )
            departureScale = 0.16
            departureOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            viewModel.moveCurrentCard(to: target)
            resetDropTarget()
        }
    }

    private func resetDropTarget() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.86)) {
            dropTargetStack = nil
        }

        lastDropTargetStack = nil
    }

    private func stack(at location: CGPoint) -> LearningStack? {
        LearningStack.allCases.first { stack in
            guard let frame = stackFrames[stack] else { return false }
            return frame.contains(location)
        }
    }

    private func cardMetrics(for proxy: GeometryProxy) -> CardMetrics {
        let size = proxy.size
        let safeWidth = max(size.width, 1)
        let safeHeight = max(size.height, 1)
        let baseWidth = min(safeWidth * 0.86, 420)
        let baseHeight = min(safeHeight * 0.62, 620)
        let editWidth = min(safeWidth - 32, 560)
        let fullScreenHeight = max(observedScreenHeight, safeHeight)
        let editVisibleHeight = min(safeHeight, fullScreenHeight - editReservedKeyboardHeight)
        let editHeight = max(editVisibleHeight - 28, baseHeight)

        return CardMetrics(
            baseWidth: baseWidth,
            baseHeight: baseHeight,
            activeWidth: isEditing ? max(baseWidth, editWidth) : baseWidth,
            activeHeight: isEditing ? editHeight : baseHeight
        )
    }

    private func editManualKeyboardReserve(for proxy: GeometryProxy) -> CGFloat {
        guard isEditing else { return 0 }

        let currentHeight = max(proxy.size.height, 1)
        let fullHeight = max(observedScreenHeight, currentHeight)
        let systemAppliedKeyboardInset = max(0, fullHeight - currentHeight)
        return max(0, editReservedKeyboardHeight - systemAppliedKeyboardInset)
    }

    private func cardSurface(for card: ReviewCardState) -> some View {
        ReviewCardSurface(
            note: card.note,
            isBackFaceVisible: isBackFaceVisible,
            saveGlowColor: saveGlowColor,
            saveGlowScale: saveGlowScale,
            saveGlowOpacity: saveGlowOpacity,
            saveGlowBlur: saveGlowBlur
        )
    }

    private var editControls: some View {
        ReviewToolbar(
            hasCurrentCard: viewModel.currentCard != nil,
            isStreakFireEnabled: $isStreakFireEnabled,
            isBackSideFirst: $isBackSideFirst,
            onFocus: enterFocusMode,
            onDelete: {
                isDeleteConfirmationPresented = true
            },
            onEdit: enterEditMode,
            onAdd: beginAddCardFlow,
            onBatchAdd: beginBatchAddFlow
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

    private var editAccessoryControls: some View {
        ReviewKeyboardAccessory(
            isSaveEnabled: saveButtonEnabled,
            onCancel: cancelEditing,
            onFlip: toggleFlip,
            onSave: saveEditing
        )
    }

    private func enterEditMode() {
        guard let note = viewModel.currentCard?.note else { return }
        isAddingNewCard = false
        draftCard = nil
        isEditKeyboardFocusRequested = false
        loadDrafts(from: note)
        translation = .zero
        resetPressInteraction()
        isCommittingSwipe = false
        touchMoved = false
        beginEditPresentation()
    }

    private func cancelEditing() {
        finishEditing(shouldSave: false)
    }

    private func saveEditing() {
        guard saveButtonEnabled else { return }
        finishEditing(shouldSave: true)
    }

    private func initialEditKeyboardHeight() -> CGFloat {
        if lastObservedKeyboardHeight > 0 {
            return lastObservedKeyboardHeight
        }
        let estimatedScreenHeight = max(observedScreenHeight, 844)
        return min(max(estimatedScreenHeight * 0.34, 300), 380)
    }

    private func beginEditPresentation() {
        editCloseTask?.cancel()
        editCloseTask = nil
        isReviewChromeReturnVisible = false
        editReservedKeyboardHeight = initialEditKeyboardHeight()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isEditViewPresented = true
            isEditing = true
            isEditKeyboardFocusRequested = true
        }
    }

    private func finishEditing(shouldSave: Bool) {
        guard isEditing else { return }
        editCloseTask?.cancel()
        isReviewChromeReturnVisible = false

        if shouldSave {
            commitEditing()
            runSaveGlow()
        } else {
            discardEditing()
            runCancelShake()
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isEditKeyboardFocusRequested = false
            isEditing = false
            editReservedKeyboardHeight = 0
        }

        editCloseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.34))
            guard !Task.isCancelled, !isEditing else { return }

            isEditViewPresented = false

            guard !isBatchAdding else {
                editCloseTask = nil
                return
            }

            withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                isReviewChromeReturnVisible = true
            }
            editCloseTask = nil
        }
    }

    private func commitEditing() {
        let trimmedFront = draftFrontText.trimmingCharacters(in: .whitespacesAndNewlines)
        let backLines = normalizedLines(from: draftBackText)

        guard let note = presentedCard?.note else { return }

        if isAddingNewCard {
            viewModel.addNewCard(front: trimmedFront, back: backLines)
            draftCard = nil
            isAddingNewCard = false
        } else {
            viewModel.mergeFacetPatch(
                [
                    CardFacetKey.front: [trimmedFront],
                    CardFacetKey.back: backLines
                ],
                forNoteId: note.id
            )
        }
    }

    private func discardEditing() {
        if isAddingNewCard {
            draftCard = nil
            isAddingNewCard = false
        } else if let note = viewModel.currentCard?.note {
            loadDrafts(from: note)
        }
    }

    private func loadDrafts(from note: CardNote) {
        draftFrontText = CardNoteDisplay.frontPlainText(for: note)
        draftBackText = CardNoteDisplay.backLines(for: note).joined(separator: "\n")
    }

    private func clearDrafts() {
        draftFrontText = ""
        draftBackText = ""
    }

    private func deleteCurrentCard() {
        guard viewModel.currentCard != nil, !isReviewChromeSuppressed else { return }
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

    private func beginBatchAddFlow() {
        guard !isReviewChromeSuppressed else { return }
        isBatchAdding = true
    }

    private func beginAddCardFlow() {
        guard !isReviewChromeSuppressed else { return }
        isEditKeyboardFocusRequested = false

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
            draftCard = ReviewCardState(
                note: CardNote(
                    id: "draft.new-card",
                    cardType: .genericV1,
                    facets: [
                        CardFacetKey.front: [""],
                        CardFacetKey.back: []
                    ]
                ),
                progress: .initial
            )
            isAddingNewCard = true
            clearDrafts()
            prepareDraftCardFromAddButton()
            beginEditPresentation()
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
            isBackFaceVisible = false
            entryOffset = .zero
            entryScale = 1
            randomizeCardTilts()
        }
    }

    private func discardDraftCard() {
        draftCard = nil
        isAddingNewCard = false
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isEditKeyboardFocusRequested = false
            isEditing = false
            editReservedKeyboardHeight = 0
        }
        runCancelShake()
        resetPresentedCardState()
    }

    private func resetPresentedCardState() {
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true

        withTransaction(resetTransaction) {
            isFlipped = isBackSideFirst
            isBackFaceVisible = isBackSideFirst
            translation = .zero
            isCommittingSwipe = false
            isEditKeyboardFocusRequested = false
            editReservedKeyboardHeight = 0
            if !isAddingNewCard {
                isEditing = false
                isEditViewPresented = false
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

        if let note = presentedCard?.note {
            loadDrafts(from: note)
        }
        scheduleEntryAnimation()
    }

    private func preparePresentedCard(using note: CardNote) {
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true
        withTransaction(resetTransaction) {
            isFlipped = isBackSideFirst
            isBackFaceVisible = isBackSideFirst
        }
        randomizeCardTilts()
        loadDrafts(from: note)
        scheduleEntryAnimation()
    }

    private func normalizedLines(from text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func toggleFlip() {
        let targetBackFaceVisible = !isFlipped

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            guard isFlipped == targetBackFaceVisible else { return }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isBackFaceVisible = targetBackFaceVisible
            }
        }
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

    private func triggerDropTargetHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    private func triggerStackLockHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)
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
            runCompletionBurstIfNeeded(for: transfer.to, attempt: 0)
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

    private func runCompletionBurstIfNeeded(for stack: LearningStack, attempt: Int) {
        guard stack == .know else { return }

        guard let stackFrame = stackFrames[stack] else {
            if attempt < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    runCompletionBurstIfNeeded(for: stack, attempt: attempt + 1)
                }
            }
            return
        }

        let shorterViewportSide = min(reviewViewportSize.width, reviewViewportSize.height)
        let travelDistance = max(shorterViewportSide * 0.28, 120)
        let event = ReviewStackBurstEvent(
            stack: stack,
            origin: CGPoint(x: stackFrame.midX, y: stackFrame.midY),
            travelDistance: travelDistance
        )
        stackBurstEvent = event

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard stackBurstEvent?.id == event.id else { return }
            stackBurstEvent = nil
        }
    }

    private func runStreakBreakAnimation(_ event: StreakBreakEvent) {
        streakBreakAnimation = StreakBreakAnimation(
            previousStreak: event.previousStreak,
            token: event.token
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            guard streakBreakAnimation?.token == event.token else { return }
            streakBreakAnimation = nil
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

}

#Preview {
    ReviewView()
}
