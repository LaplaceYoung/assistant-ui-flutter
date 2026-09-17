/// Flutter port of [assistant-ui](https://www.assistant-ui.com): primitives,
/// a local runtime, and styled chat components.
///
/// Three layers, matching the original:
///
/// * runtime — `LocalRuntime` owns thread state, streaming, branching, tool
///   execution; `DataStreamChatModelAdapter` speaks the Vercel data stream
///   protocol to a backend.
/// * primitives — `AuiThread`, `AuiMessage`, `AuiComposerInput`,
///   `AuiActionBar`, `AuiBranchPicker`, `AuiIf`, and friends: unstyled,
///   composable, driven by runtime state.
/// * components — `AssistantThread`, `AssistantComposer`,
///   `AssistantMessageParts`: the styled default UI.
///
/// ```dart
/// final runtime = LocalRuntime(adapter: MyAdapter());
///
/// AuiRuntimeProvider(
///   runtime: runtime,
///   child: const AssistantThread(),
/// );
/// ```
library;

export 'src/clones/chat_gpt_clone.dart' show ChatGptClone;
export 'src/clones/claude_clone.dart' show ClaudeClone;
export 'src/clones/gemini_clone.dart' show GeminiClone;
export 'src/clones/grok_clone.dart' show GrokClone;
export 'src/components/action_bar.dart'
    show AssistantActionBar, AssistantBranchPickerBar, AssistantContinueRun;
export 'src/components/assistant_modal.dart'
    show AssistantModal, AssistantModalView;
export 'src/components/attachment.dart'
    show AssistantAttachmentCard, AssistantMessageAttachments;
export 'src/components/composer.dart'
    show
        AssistantComposer,
        AssistantComposerAttachButton,
        AssistantInlineComposer,
        AssistantPrimaryAction;
export 'src/components/composer_voice.dart' show AssistantComposerVoice;
export 'src/components/indicators.dart'
    show
        AssistantLoadingState,
        AssistantThinkingIndicator,
        AssistantTypingIndicator;
export 'src/components/menu.dart' show AssistantMenuButton, AssistantMenuItem;
export 'src/components/message_queue.dart' show AssistantMessageQueue;
export 'src/components/message_timing.dart' show AssistantMessageTiming;
export 'src/components/tooltip_icon_button.dart'
    show AssistantIconButtonShape, AssistantTooltipIconButton;
export 'src/components/markdown.dart' show AssistantMarkdown, parseInline;
export 'src/components/parts.dart'
    show
        AssistantMessageParts,
        AssistantReasoning,
        AssistantToolCallCard,
        attachmentIcon,
        attachmentSizeLabel,
        attachmentTypeLabel;
export 'src/components/composer_context.dart'
    show AssistantContextBar, AssistantContextRing;
export 'src/components/composer_triggers.dart'
    show
        AssistantDirectiveText,
        AssistantMention,
        AssistantMentionAdapter,
        AssistantMentionPopover,
        AssistantSlashCommand,
        AssistantSlashCommandAdapter,
        AssistantSlashCommandMenu;
export 'src/components/surfaces.dart'
    show
        AuiIconAction,
        AuiPillButton,
        AuiPillButtonVariant,
        AuiShimmerBar,
        AuiShimmerLabel,
        AuiSpinner,
        AuiSwapLabel,
        auiFg,
        auiField,
        auiFieldColor,
        auiMono,
        auiPaper;
export 'src/components/activity_graph.dart' show AssistantActivityGraph;
export 'src/components/agent_card.dart' show AgentSkill, AssistantAgentCard;
export 'src/components/agent_handoff.dart' show AssistantAgentHandoff;
export 'src/components/agent_plan.dart' show AssistantAgentPlan;
export 'src/components/agent_status.dart' show AgentState, AssistantAgentStatus;
export 'src/components/approval_card.dart'
    show ApprovalState, AssistantApprovalCard;
export 'src/components/artifact_card.dart' show AssistantArtifactCard;
export 'src/components/background_inbox.dart'
    show AssistantBackgroundInbox, BackgroundRun, BackgroundState;
export 'src/components/canvas_split.dart'
    show
        AssistantCanvasLine,
        AssistantCanvasMessage,
        AssistantCanvasSplit;
export 'src/components/chat_panel.dart'
    show
        AssistantChatPanel,
        AssistantChatPanelMessage,
        AssistantChatPanelTyping;
export 'src/components/chart.dart' show AssistantChart, AuiChartPainter, ChartVariant;
export 'src/components/checkpoint_history.dart'
    show AssistantCheckpointHistory, Checkpoint;
export 'src/components/computer_use.dart'
    show AssistantComputerUse, ComputerStep;
export 'src/components/confidence_marker.dart'
    show AssistantConfidenceMarker, Confidence, ConfidenceClaim;
export 'src/components/context_breakdown.dart'
    show AssistantContextBreakdown, ContextSegment;
export 'src/components/conversation_search.dart'
    show AssistantConversationSearch, SearchHit;
export 'src/components/cost_meter.dart' show AssistantCostMeter, CostLine;
export 'src/components/diagram.dart' show AssistantDiagram;
export 'src/components/document_reference.dart'
    show AssistantDocumentReference, DocumentAnchor;
export 'src/components/day_separator.dart'
    show AssistantDaySeparator, DatedMessage;
export 'src/components/empty_state.dart'
    show AssistantEmptyState, AssistantEmptyStateSuggestion;
export 'src/components/error_state.dart' show AssistantErrorState;
export 'src/components/feedback_dialog.dart' show AssistantFeedbackDialog;
export 'src/components/file_tree.dart' show AssistantFileTree, FileTreeNode;
export 'src/components/follow_up_suggestions.dart'
    show AssistantFollowUpSuggestions;
export 'src/components/flow.dart'
    show
        AssistantFlow,
        AssistantFlowArrow,
        AssistantFlowColumn,
        AssistantFlowGroup,
        AssistantFlowNode,
        AssistantFlowRow,
        FlowNodeVariant,
        FlowTone,
        auiFlowNodeWidth;
export 'src/components/flow_expand.dart' show AssistantFlowExpand;
export 'src/components/flow_graph.dart'
    show
        AssistantFlowGraph,
        AuiFlowGraphPainter,
        FlowGraphEdge,
        FlowGraphNode,
        FlowNodeState;
export 'src/components/flow_canvas.dart'
    show AuiFlowEdgePainter, AssistantFlowCanvas, FlowEdge, FlowNode, FlowRoute;
export 'src/components/generative_ui.dart'
    show
        AuiGenerativeUI,
        AuiGenerativeUILibrary,
        AuiGenerativeUIRenderer,
        auiStyledGenerativeUILibrary;
export 'src/components/image.dart'
    show AssistantImage, AuiImageSize, AuiImageState, AuiImageVariant;
export 'src/components/image_generation.dart' show AssistantImageGeneration;
export 'src/components/inline_citation.dart' show AssistantInlineCitation;
export 'src/components/launcher_bubble.dart' show AssistantLauncherBubble;
export 'src/components/logos.dart'
    show
        AuiBrandLogos,
        AuiBrandMark,
        AuiLogoMark,
        AuiLogoPainter,
        parseAuiSvgPath;
export 'src/components/map_answer.dart' show AssistantMapAnswer, MapPin;
export 'src/components/onboarding.dart'
    show AssistantOnboarding, OnboardingStep;
export 'src/components/mermaid_diagram.dart'
    show AssistantMermaidDiagram, AssistantMermaidSkeleton;
export 'src/components/research_report.dart'
    show AssistantResearchReport, ReportSection, SectionState;
export 'src/components/retrieval_chunks.dart'
    show AssistantRetrievalChunks, RetrievalChunk;
export 'src/components/speaker_identity.dart'
    show AssistantSpeakerIdentity, SpeakerKind, SpeakerTurn;
export 'src/components/voice_conversation.dart'
    show AssistantVoiceConversation, VoiceMode, VoiceTurn;
export 'src/components/web_search.dart'
    show AssistantWebSearch, WebSearchResult;
export 'src/components/guardrail_notice.dart' show AssistantGuardrailNotice;
export 'src/components/message_attachment.dart'
    show
        AssistantMessageAttachmentList,
        AttachmentKind,
        MessageAttachmentItem;
export 'src/components/quote_reply.dart'
    show AssistantQuoteReply, QuoteAction;
export 'src/components/heat_calendar.dart' show AuiHeatCalendar, AuiHeatCell;
export 'src/components/heat_graph.dart'
    show AssistantHeatGraph, auiHeatGraphColors;
export 'src/components/job_progress.dart'
    show AssistantJobProgress, JobStage;
export 'src/components/mobile_composer.dart' show AssistantMobileComposer;
export 'src/components/model_selector.dart'
    show
        AssistantModelSelector,
        ModelOption,
        ModelSelectorEffortOption,
        ModelSelectorSize,
        ModelSelectorVariant,
        auiDefaultEffortOptions,
        auiResolveModelEffort;
export 'src/components/model_picker.dart'
    show AssistantModelPicker, PickableModel;
export 'src/components/number_ticker.dart' show AssistantNumberTicker;
export 'src/components/permission_grant.dart'
    show AssistantPermissionGrant, GrantScope;
export 'src/components/prompt_library.dart'
    show AssistantPromptLibrary, SavedPrompt;
export 'src/components/quote.dart'
    show
        AssistantComposerQuotePreview,
        AssistantQuoteBlock,
        AssistantSelectionToolbar;
export 'src/components/quota_banner.dart' show AssistantQuotaBanner;
export 'src/components/read_aloud.dart' show AssistantReadAloud;
export 'src/components/reasoning_effort.dart'
    show AssistantReasoningEffort, EffortLevel;
export 'src/components/reasoning_panel.dart'
    show AssistantReasoningPanel, ReasoningStep;
export 'src/components/recommendation_card.dart'
    show AssistantRecommendationCard, RecommendationState;
export 'src/components/settings_panel.dart'
    show AssistantSettingsPanel, SettingToggle;
export 'src/components/shared_conversation.dart'
    show AssistantSharedConversation, SharedTurn;
export 'src/components/sources.dart' show AssistantSources, SourceRef;
export 'src/components/streaming_text.dart'
    show AssistantStreamingText, StreamingSegment;
export 'src/components/suggestions.dart'
    show AssistantSuggestions, AuiSuggestionVariant;
export 'src/components/spec_sheet.dart' show AssistantSpecSheet, SpecRow;
export 'src/components/terminal_block.dart'
    show AssistantTerminalBlock, TerminalVariant;
export 'src/components/threadlist_sidebar.dart'
    show AssistantThreadListSidebar;
export 'src/components/thread_search.dart'
    show AssistantThreadSearch, SearchableThread;
export 'src/components/syntax_highlighter.dart'
    show
        AssistantSyntaxHighlighter,
        AuiCodeToken,
        AuiHighlightPalette,
        AuiTokenKind,
        tokenizeAuiCode;
export 'src/components/timeline.dart'
    show AssistantTimeline, TimelineEvent, TimelineWhen;
export 'src/components/todo_list.dart'
    show AssistantTodoList, TodoItem, TodoStatus;
export 'src/components/math_block.dart'
    show AssistantMathBlock, AuiFrac, AuiSub, AuiSup, MathStep;
export 'src/components/memory_chips.dart'
    show AssistantMemoryChips, MemoryChange, MemoryChip;
export 'src/components/regenerate_menu.dart'
    show AssistantRegenerateMenu, RegenerateOption;
export 'src/components/reviewable_diff.dart'
    show AssistantReviewableDiff, DiffHunk, HunkDecision;
export 'src/components/schedule_card.dart'
    show AssistantScheduleCard, ScheduleRun;
export 'src/components/score_breakdown.dart'
    show AssistantScoreBreakdown, ScoreCriterion;
export 'src/components/subagent_list.dart'
    show AssistantSubagentList, SubagentItem;
export 'src/components/task_card.dart'
    show AssistantTaskCard, TaskCardState, TaskStateGlyph;
export 'src/components/trace_waterfall.dart'
    show AssistantTraceWaterfall, SpanStatus, TraceSpan;
export 'src/components/command_palette.dart'
    show AssistantCommandPalette, PaletteCommand;
export 'src/components/code_diff.dart'
    show AssistantCodeDiff, DiffKind, DiffLine;
export 'src/components/code_runner.dart'
    show AssistantCodeRunner, RunState;
export 'src/components/comparison_card.dart'
    show AssistantComparisonCard, ComparisonOption;
export 'src/components/connection_state.dart'
    show AssistantConnectionState, ConnectionPhase;
export 'src/components/conversation_map.dart'
    show AssistantConversationMap, ConversationMapEntry;
export 'src/components/data_table.dart' show AssistantDataTable, ModelUsage;
export 'src/components/elicitation_form.dart'
    show
        AssistantElicitationForm,
        ElicitationField,
        ElicitationFieldKind,
        ElicitationState;
export 'src/components/mcp_config.dart'
    show AssistantMcpConfig, McpConfigStatus, McpServerConfig;
export 'src/components/mcp_server_panel.dart'
    show AssistantMcpServerPanel, McpServer, McpServerStatus;
export 'src/components/theme.dart' show AssistantTheme, AssistantThemeProvider;
export 'src/components/tool_error.dart' show AssistantToolError;
export 'src/components/tool_group.dart'
    show AssistantToolGroup, GroupedTool, GroupedToolState;
export 'src/components/tool_timeline.dart'
    show AssistantTimelineStat, AssistantTimelineStep, AssistantToolTimeline;
export 'src/components/thread_list.dart'
    show AssistantShell, AssistantShellSide, AssistantThreadList;
export 'src/components/thread.dart'
    show
        AssistantScrollToLatest,
        AssistantAssistantMessage,
        AssistantAvatar,
        AssistantMessageMeta,
        AssistantThread,
        AssistantThreadEmptyState,
        AssistantUserMessage;
export 'src/core/abort.dart' show AbortController, AbortException, AbortSignal;
export 'src/core/adapters.dart'
    show
        ChatModelAdapter,
        DictationAdapter,
        DictationSession,
        FeedbackAdapter,
        FeedbackRequest,
        FeedbackType,
        SpeechSynthesisAdapter,
        ChatModelRunContext,
        ChatModelRunResult,
        ModelContext,
        SingleShotChatModelAdapter,
        ToolDefinition,
        ToolRenderText,
        Toolkit;
export 'src/core/attachments.dart'
    show
        AttachmentAddResult,
        AttachmentAddStatus,
        AttachmentAdapter,
        AttachmentType,
        AuiAttachment,
        DocumentAttachment,
        ImageAttachment,
        PendingAttachment;
export 'src/core/message.dart'
    show
        IncompleteReason,
        MessageBranch,
        MessageMetadata,
        MessageRole,
        MessageStatus,
        MessageStatusComplete,
        MessageStatusIncomplete,
        MessageStatusRequiresAction,
        MessageStatusRunning,
        MessageTiming,
        RequiresActionReason,
        ThreadMessage;
export 'src/core/message_part.dart'
    show
        DataPart,
        FilePart,
        ImagePart,
        MessagePart,
        PartStatus,
        ReasoningPart,
        QuotePart,
        SourcePart,
        TextPart,
        ToolCallPart;
export 'src/core/runtime_api.dart'
    show
        AssistantRuntime,
        AuiState,
        ComposerRuntimeApi,
        ComposerState,
        ContextUsage,
        DictationState,
        QueuedMessage,
        MessageState,
        ThreadCapabilities,
        ThreadListItem,
        ThreadSuggestion,
        ThreadListItemStatus,
        ThreadRuntimeApi,
        ThreadState,
        ThreadsRuntimeApi,
        ThreadsState;
export 'src/primitives/action_bar.dart'
    show
        AuiActionBar,
        AuiActionBarAutohide,
        AuiActionBarCopy,
        AuiActionBarEdit,
        AuiActionBarFeedback,
        AuiActionBarReload,
        AuiActionBarSpeak;
export 'src/primitives/branch_picker.dart'
    show
        AuiBranchPicker,
        AuiBranchPickerNext,
        AuiBranchPickerNumber,
        AuiBranchPickerPrevious;
export 'src/primitives/composer.dart'
    show
        AuiComposerAddAttachment,
        AuiComposerAttachments,
        AuiComposerCancel,
        AuiComposerInput,
        AuiComposerSend,
        AuiSubmitMode;
export 'src/primitives/composer_triggers.dart'
    show
        AuiComposerTriggerPopover,
        AuiComposerTriggerRoot,
        AuiTriggerAdapter,
        AuiTriggerController,
        AuiTriggerScope,
        AuiTriggerState,
        TriggerItem;
export 'src/primitives/message.dart'
    show
        AuiDataUIBuilder,
        AuiMessage,
        AuiMessageHoverScope,
        AuiMessagePartImage,
        AuiMessagePartInProgress,
        AuiMessagePartText,
        AuiMessageParts,
        AuiPartBuilder,
        AuiPartGroupBuilder,
        AuiPartGroupKey,
        AuiPartGroupMember,
        AuiStreamingCursor,
        AuiToolUIBuilder;
export 'src/primitives/runtime_provider.dart' show AuiRuntimeProvider;
export 'src/primitives/state.dart'
    show AuiApi, AuiCurrentMessage, AuiIf, AuiMessageScope, AuiStateBuilder;
export 'src/primitives/thread_list.dart'
    show
        AuiThreadListItemArchive,
        AuiThreadListItemDelete,
        AuiThreadListItemScope,
        AuiThreadListItemTitle,
        AuiThreadListItemTrigger,
        AuiThreadListItems,
        AuiThreadListLoadMore,
        AuiThreadListNew,
        AuiThreadListRoot,
        AuiThreadListSearch;
export 'src/primitives/thread.dart'
    show
        AuiMessageRegistry,
        AuiThread,
        AuiThreadFooter,
        AuiThreadLayout,
        AuiThreadMessages,
        AuiThreadScrollToBottom,
        AuiThreadViewport,
        AuiTurnAnchor;
export 'src/protocol/data_stream.dart' show DataStreamChunkType, DataStreamParser;
export 'src/protocol/data_stream_adapter.dart'
    show DataStreamChatModelAdapter;
export 'src/runtime/local_runtime.dart'
    show LocalRuntime, LocalRuntimeOptions;

/// The span primitives: name, type badge, status, collapse, indent, children
/// and the timeline bar — `react-o11y`'s primitive family.
export 'src/components/span_primitives.dart'
    show
        AuiSpanChildren,
        AuiSpanCollapseToggle,
        AuiSpanIndent,
        AuiSpanName,
        AuiSpanRoot,
        AuiSpanScope,
        AuiSpanStatusIndicator,
        AuiSpanTimeline,
        AuiSpanTimelineBar,
        AuiSpanTypeBadge;

/// Span tree: the resource `@assistant-ui/react-o11y` derives, as a model a
/// Flutter view can walk.
export 'src/runtime/span_tree.dart'
    show OpenSpanStatus, SpanData, SpanNode, SpanTimeRange, SpanTree;

/// The shimmer effect: a moving highlight band over any child, the Dart
/// counterpart of the `tw-shimmer` utility.
export 'src/components/shimmer.dart'
    show AssistantShimmer, AssistantShimmerBox;

/// Hosted platform client: threads and messages — the Dart half of
/// `@assistant-ui/cloud`.
export 'src/runtime/cloud.dart'
    show CloudClient, CloudException, CloudThread, CloudThreadPage;

/// Generative UI: the model-emitted tree, its "view source" serializer and the
/// host vocabulary — the Dart half of `@assistant-ui/react-generative-ui`.
export 'src/runtime/generative_ui.dart'
    show
        GenerativeUi,
        GenerativeUiBuilder,
        GenerativeUiNode,
        GenerativeUiRegistry,
        GenerativeUiRenderContext,
        generativeUiFromPart,
        generativeUiMaxDepth,
        generativeUiPartName,
        generativeUiToJsx,
        generativeUiTypeKey,
        parseGenerativeUi;

/// Google ADK runtime: the `/run_sse` client and event accumulator — the Dart
/// half of `@assistant-ui/react-google-adk`.
export 'src/runtime/adk.dart'
    show
        AdkAuthRequest,
        AdkChatModelAdapter,
        AdkClient,
        AdkEvent,
        AdkEventAccumulator,
        AdkException,
        AdkToolConfirmation,
        adkConfirmationDecision,
        adkConfirmationReply,
        adkConfirmationTarget,
        adkContentFromParts,
        adkGatedCallId,
        adkGatedToolName,
        adkPartsToContent,
        adkRequestConfirmation,
        projectAdkToolConfirmations;

/// LangGraph runtime: the platform client, the message accumulator and the
/// conversions — the Dart half of `@assistant-ui/react-langgraph`.
export 'src/runtime/langgraph.dart'
    show
        LangGraphChatModelAdapter,
        LangGraphClient,
        LangGraphEvent,
        LangGraphException,
        LangGraphMessageAccumulator,
        applyLangChainToolResult,
        langChainMessageToParts,
        langChainToolResult,
        langGraphAppendChunk,
        langGraphInterruptsOf,
        langGraphMessagesOf,
        parsePartialJsonObject,
        threadMessageToLangChain;

/// A2A runtime: the client, the wire types and the conversions — the Dart
/// half of `@assistant-ui/react-a2a`.
export 'src/runtime/a2a.dart'
    show
        A2AAgentCard,
        A2AArtifact,
        A2AArtifactUpdateEvent,
        A2AChatModelAdapter,
        A2AClient,
        A2AException,
        A2AMessage,
        A2AMessageEvent,
        A2APart,
        A2ARole,
        A2AStatusUpdateEvent,
        A2AStreamEvent,
        A2ATask,
        A2ATaskEvent,
        A2ATaskState,
        A2ATaskStatus,
        a2aPartToContent,
        a2aPartsToContent,
        a2aProtocolVersion,
        a2aTaskStateToMessageStatus,
        contentPartsToA2AParts,
        threadMessageToA2AMessage;

/// AG-UI runtime: the event parser and the streaming bridge onto
/// `ChatModelAdapter` — the Dart half of `@assistant-ui/react-ag-ui`.
export 'src/runtime/ag_ui.dart'
    show
        AgUiActivitySnapshot,
        AgUiAgent,
        AgUiChatModelAdapter,
        AgUiCustom,
        AgUiEvent,
        AgUiException,
        AgUiInterrupt,
        AgUiMessagesSnapshot,
        AgUiRaw,
        AgUiReasoningEncryptedValue,
        AgUiReasoningEnd,
        AgUiReasoningMessageContent,
        AgUiReasoningMessageEnd,
        AgUiReasoningMessageStart,
        AgUiReasoningStart,
        AgUiRunAgentInput,
        AgUiRunCancelled,
        AgUiRunError,
        AgUiRunFinished,
        AgUiRunInterrupted,
        AgUiRunOutcome,
        AgUiRunStarted,
        AgUiRunSucceeded,
        AgUiStateDelta,
        AgUiStateSnapshot,
        AgUiSubagentError,
        AgUiSubagentFinished,
        AgUiSubagentOutcome,
        AgUiSubagentStarted,
        AgUiSubagentSucceeded,
        AgUiSubagentSuspended,
        AgUiTextMessageChunk,
        AgUiTextMessageContent,
        AgUiTextMessageEnd,
        AgUiTextMessageStart,
        AgUiThinkingEnd,
        AgUiThinkingStart,
        AgUiThinkingTextMessageContent,
        AgUiThinkingTextMessageEnd,
        AgUiThinkingTextMessageStart,
        AgUiToolCallArgs,
        AgUiToolCallChunk,
        AgUiToolCallEnd,
        AgUiToolCallResult,
        AgUiToolCallStart,
        parseAgUiEvent;

/// Model Context Protocol client: the Dart half of `@assistant-ui/react-mcp`.
export 'src/runtime/mcp_client.dart'
    show
        McpClient,
        McpException,
        McpHttpTransport,
        McpResource,
        McpServers,
        McpTool,
        McpTransport,
        mcpProgress;

