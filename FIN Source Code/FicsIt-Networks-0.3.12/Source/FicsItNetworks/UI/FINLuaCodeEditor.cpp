#include "FINLuaCodeEditor.h"

#include "Input/HittestGrid.h"

const FName FFINLuaCodeEditorStyle::TypeName(TEXT("FFINLuaCodeEditorStyle"));

FFINLuaCodeEditorStyle::FFINLuaCodeEditorStyle() {}

void FFINLuaCodeEditorStyle::GetResources(TArray<const FSlateBrush*>& OutBrushes) const {
	Super::GetResources(OutBrushes);
}

const FFINLuaCodeEditorStyle& FFINLuaCodeEditorStyle::GetDefault() {
	static FFINLuaCodeEditorStyle* Default = nullptr;
	if (!Default) Default = new FFINLuaCodeEditorStyle();
	return *Default;
}

void FFINLuaSyntaxHighlighterTextLayoutMarshaller::SetText(const FString& SourceString, FTextLayout& TargetTextLayout) {
	TArray<FSyntaxTokenizer::FTokenizedLine> TokenizedLines;
	TArray<FTextRange> LineRanges;
	FTextRange::CalculateLineRangesFromString(SourceString, LineRanges);

	TArray<FString> Rules = TArray<FString>({
		" ", "\t", "\\.", "\\:", "\\\"", "\\\'", "\\,", "\\\\", "\\(", "\\)", "for", "in", "while", "do", "if", "then", "elseif", "else",
		"end", "local", "true", "false", "not", "and", "or", "function", "return", "--\\[\\[", "\\]\\]--", "--", "\\+", "\\-", "\\/",
		"\\*", "\\%", "\\[", "\\]", "\\{", "\\}", "\\=", "\\!", "\\~", "\\#", "\\>", "\\<"});
	
	FString Pat;
	for (const FString& Rule : Rules) {
		Pat += FString::Printf(TEXT("(%s)|"), *Rule);
	}
	if (Rules.Num() > 0) Pat = Pat.LeftChop(1);
	FRegexPattern Pattern(Pat);

	for (const FTextRange& LineRange : LineRanges) {
		FSyntaxTokenizer::FTokenizedLine TokenizedLine;
		TokenizedLine.Range = LineRange;

		FString Line = SourceString.Mid(LineRange.BeginIndex, LineRange.EndIndex - LineRange.BeginIndex);
		FRegexMatcher Match(Pattern, Line);
		int32 Start = 0;
		int32 End = 0;
		while (Match.FindNext()) {
			int32 MatchStart = Match.GetMatchBeginning();
			End = Match.GetMatchEnding();
			if (MatchStart != Start) {
				TokenizedLine.Tokens.Add(FSyntaxTokenizer::FToken(FSyntaxTokenizer::ETokenType::Literal, FTextRange(LineRange.BeginIndex + Start, LineRange.BeginIndex + MatchStart)));
			}
			Start = End;
			TokenizedLine.Tokens.Add(FSyntaxTokenizer::FToken(FSyntaxTokenizer::ETokenType::Syntax, FTextRange(LineRange.BeginIndex + MatchStart, LineRange.BeginIndex + End)));
		}
		if (End < LineRange.EndIndex - LineRange.BeginIndex || TokenizedLine.Tokens.Num() < 1) {
			TokenizedLine.Tokens.Add(FSyntaxTokenizer::FToken(FSyntaxTokenizer::ETokenType::Syntax, FTextRange(LineRange.BeginIndex + End, LineRange.EndIndex)));
		}
		TokenizedLines.Add(TokenizedLine);
	}
	
	ParseTokens(SourceString, TargetTextLayout, TokenizedLines);
}

bool FFINLuaSyntaxHighlighterTextLayoutMarshaller::RequiresLiveUpdate() const {
	return true;
}

FFINLuaSyntaxHighlighterTextLayoutMarshaller::FFINLuaSyntaxHighlighterTextLayoutMarshaller(const FFINLuaCodeEditorStyle* InLuaSyntaxTextStyle) : SyntaxTextStyle(InLuaSyntaxTextStyle) {

}

TSharedRef<FFINLuaSyntaxHighlighterTextLayoutMarshaller> FFINLuaSyntaxHighlighterTextLayoutMarshaller::Create(const FFINLuaCodeEditorStyle* LuaSyntaxTextStyle) {
	TArray<FSyntaxTokenizer::FRule> TokenizerRules;
	for (FString Token : TArray<FString>({
		" ", "\t", ".", ":", "\"", "\'", "\\", ",", "(", ")", "for", "in", "while", "do", "if", "then", "elseif", "else",
		"end", "local", "true", "false", "not", "and", "or", "function", "return", "--[[", "]]--", "--", "+", "-", "/",
		"*", "%", "[", "]", "{", "}", "=", "!", "~", "#", ">", "<"})) {
		TokenizerRules.Add(FSyntaxTokenizer::FRule(Token));
	}

	TokenizerRules.Sort([](const FSyntaxTokenizer::FRule& A, const FSyntaxTokenizer::FRule& B) {
		return A.MatchText.Len() > B.MatchText.Len();
	});
	
	return MakeShareable(new FFINLuaSyntaxHighlighterTextLayoutMarshaller(LuaSyntaxTextStyle));
}

void FFINLuaSyntaxHighlighterTextLayoutMarshaller::ParseTokens(const FString& SourceString, FTextLayout& TargetTextLayout, TArray<FSyntaxTokenizer::FTokenizedLine> TokenizedLines) {
	TArray<FTextLayout::FNewLineData> LinesToAdd;
	LinesToAdd.Reserve(TokenizedLines.Num());

	bool bInString = false;
	bool bInBlockComment = false;
	TSharedPtr<ISlateRun> Run;
	for (const FSyntaxTokenizer::FTokenizedLine& TokenizedLine : TokenizedLines) {
		TSharedRef<FString> ModelString = MakeShareable(new FString());
		TArray<TSharedRef<IRun>> Runs;

		auto DoNormal = [&](FTextRange Range) {
			if (Runs.Num() > 0 && Runs[Runs.Num()-1]->GetRunInfo().Name == "SyntaxHighlight.FINLua.Normal") {
				Range.BeginIndex = Runs[Runs.Num()-1]->GetTextRange().BeginIndex;
				Runs.Pop();
			}
			FTextBlockStyle Style = SyntaxTextStyle->NormalTextStyle;
			FRunInfo RunInfo(TEXT("SyntaxHighlight.FINLua.Normal"));
			Run = FSlateTextRun::Create(RunInfo, ModelString, Style, Range);
			Runs.Add(Run.ToSharedRef());
		};
		auto DoComment = [&](const FTextRange& Range) {
			FTextBlockStyle Style = SyntaxTextStyle->CommentTextStyle;
			FRunInfo RunInfo(TEXT("SyntaxHighlight.FINLua.Comment"));
			RunInfo.MetaData.Add("Splitting");
			Run = FSlateTextRun::Create(RunInfo, ModelString, Style, Range);
			Runs.Add(Run.ToSharedRef());
		};
		auto DoString = [&](const FTextRange& Range) {
			FTextBlockStyle Style = SyntaxTextStyle->StringTextStyle;
			FRunInfo RunInfo(TEXT("SyntaxHighlight.FINLua.String"));
			RunInfo.MetaData.Add("Splitting");
			Run = FSlateTextRun::Create(RunInfo, ModelString, Style, Range);
			Runs.Add(Run.ToSharedRef());
		};
		auto DoKeyword = [&](const FTextRange& Range) {
			FTextBlockStyle Style = SyntaxTextStyle->KeywordTextStyle;
			FRunInfo RunInfo(TEXT("SyntaxHighlight.FINLua.Keyword"));
			Run = FSlateTextRun::Create(RunInfo, ModelString, Style, Range);
			Runs.Add(Run.ToSharedRef());
		};
		auto DoTrue = [&](const FTextRange& Range) {
			FTextBlockStyle Style = SyntaxTextStyle->BoolTrueTextStyle;
			FRunInfo RunInfo(TEXT("SyntaxHighlight.FINLua.Keyword"));
			Run = FSlateTextRun::Create(RunInfo, ModelString, Style, Range);
			Runs.Add(Run.ToSharedRef());
		};
		auto DoFalse = [&](const FTextRange& Range) {
			FTextBlockStyle Style = SyntaxTextStyle->BoolFalseTextStyle;
			FRunInfo RunInfo(TEXT("SyntaxHighlight.FINLua.Keyword"));
			Run = FSlateTextRun::Create(RunInfo, ModelString, Style, Range);
			Runs.Add(Run.ToSharedRef());
		};
		auto DoNumber = [&](const FTextRange& Range) {
			FTextBlockStyle Style = SyntaxTextStyle->NumberTextStyle;
			FRunInfo RunInfo(TEXT("SyntaxHighlight.FINLua.Number"));
			Run = FSlateTextRun::Create(RunInfo, ModelString, Style, Range);
			Runs.Add(Run.ToSharedRef());
		};
		auto DoWhitespace = [&](const FTextRange& Range) {
			FTextBlockStyle Style = SyntaxTextStyle->NormalTextStyle;
			FRunInfo RunInfo(TEXT("SyntaxHighlight.FINLua.Whitespace"));
			RunInfo.MetaData.Add("Splitting");
			Run = FSlateTextRun::Create(RunInfo, ModelString, Style, Range);
			Runs.Add(Run.ToSharedRef());
		};
		auto DoOperator = [&](const FTextRange& Range, bool bColored) {
			FTextBlockStyle Style = bColored ? SyntaxTextStyle->OperatorTextStyle : SyntaxTextStyle->NormalTextStyle;
			FRunInfo RunInfo(TEXT("SyntaxHighlight.FINLua.Operator"));
			RunInfo.MetaData.Add("Splitting");
			RunInfo.MetaData.Add("Operator", ModelString->Mid(Range.BeginIndex, Range.Len()));
			Run = FSlateTextRun::Create(RunInfo, ModelString, Style, Range);
			Runs.Add(Run.ToSharedRef());
		};
		auto DoFunction = [&](const FTextRange& Range, bool bDeclaration) {
			FTextBlockStyle Style = bDeclaration ? SyntaxTextStyle->FunctionDeclarationTextStyle : SyntaxTextStyle->FunctionCallTextStyle;
			FRunInfo RunInfo(TEXT("SyntaxHighlight.FINLua.Function"));
			Run = FSlateTextRun::Create(RunInfo, ModelString, Style, Range);
			Runs.Add(Run.ToSharedRef());
		};
		auto FindPrevNoWhitespaceRun = [&](int32 StartIndex = -1) {
			if (StartIndex < 0) StartIndex = Runs.Num()-1;
			for (int i = StartIndex; i >= 0; i--) {
				if (Runs[i]->GetRunInfo().Name != "SyntaxHighlight.FINLua.Whitespace") {
					return i;
				}
			}
			return -1;
		};

		int StringStart = ModelString->Len();
		int StringEnd = ModelString->Len();
		bool bInNumber = false;
		bool bNumberHadDecimal = false;
		bool bInLineComment = false;
		bool bIsEscaped = false;
		for (const FSyntaxTokenizer::FToken& Token : TokenizedLine.Tokens) {
			const FString TokenString = SourceString.Mid(Token.Range.BeginIndex, Token.Range.Len());
			int Start = ModelString->Len();
			int End = Start + TokenString.Len();
			ModelString->Append(TokenString);
			bool bWasEscaped = bIsEscaped;
			bIsEscaped = false;

			bool bIsNew = !Run.IsValid() || Start < 1 || Run->GetRunInfo().MetaData.Contains("Splitting");
			
			if (bInString || bInLineComment || bInBlockComment) {
				StringEnd += TokenString.Len();
			}
			if (!bInBlockComment && !bInLineComment && (TokenString == "\\")) {
				if (bInString) {
					bIsEscaped = !bWasEscaped;
					continue;
				}
			}
			if (!bInBlockComment && !bInLineComment && (TokenString == "\"" || TokenString == "\'")) {
				if (bInNumber) {
					DoNumber(FTextRange(StringStart, StringEnd));
					bIsNew = true;
					bInNumber = false;
				}
				if (bInString) {
					if (Start > 0 && bWasEscaped) continue;
					DoString(FTextRange(StringStart, StringEnd));
					bInString = false;
					continue;
				}
				bInString = true;
				StringStart = Start;
				StringEnd = End;
				continue;
			}
			if (!bInString) {
				if (TokenString == "--[[" && !bInBlockComment && !bInLineComment) {
					if (bInNumber) {
						bInNumber = false;
						DoNumber(FTextRange(StringStart, StringEnd));
					}
					if (!bInBlockComment) {
						bInBlockComment = true;
						StringStart = Start;
						StringEnd = End;
					}
				} else if (TokenString == "]]--" && bInBlockComment) {
					bInBlockComment = false;
					DoComment(FTextRange(StringStart, StringEnd));
					continue;
				} else if (TokenString == "--" && !bInLineComment && !bInBlockComment) {
					if (bInNumber) {
						bInNumber = false;
						DoNumber(FTextRange(StringStart, StringEnd));
					}
					bInLineComment = true;
					StringStart = Start;
					StringEnd = End;
				}
			}
			if (bInString || bInLineComment || bInBlockComment) continue;
			if (bInNumber) {
				bool bStillNumber = false;
				if (TokenString == ".") {
					if (!bNumberHadDecimal) {
						bNumberHadDecimal = true;
						bStillNumber = true;
					}
				} else if (FRegexMatcher(FRegexPattern("^[0-9]+$"), TokenString).FindNext()) bStillNumber = true;
				if (bStillNumber) {
					StringEnd += TokenString.Len();
					continue;
				}
				DoNumber(FTextRange(StringStart, StringEnd));
				bIsNew = true;
				bInNumber = false;
			}

			if (Token.Type == FSyntaxTokenizer::ETokenType::Syntax) {
				if (bIsNew) {
					if (TArray<FString>({"while", "for", "in", "do", "if", "then", "elseif", "else", "end", "local", "not", "and", "or", "function", "return"}).Contains(TokenString)) {
						DoKeyword(FTextRange(Start, End));
						continue;
					} else if (TokenString == "true") {
						DoTrue(FTextRange(Start, End));
						continue;
					} else if (TokenString == "false") {
						DoFalse(FTextRange(Start, End));
						continue;
					}
				}
				if (TokenString == "(") {
					int Index = FindPrevNoWhitespaceRun();
					if (Index >= 0 && Runs[Index]->GetRunInfo().Name == "SyntaxHighlight.FINLua.Normal") {
						FTextRange OldRange = Runs[Index]->GetTextRange();
						Runs.RemoveAt(Index);
						int KeywordIndex = FindPrevNoWhitespaceRun(Index-1);
						FString Keyword;
						if (KeywordIndex >= 0) Keyword = ModelString->Mid(Runs[KeywordIndex]->GetTextRange().BeginIndex, Runs[KeywordIndex]->GetTextRange().EndIndex - Runs[KeywordIndex]->GetTextRange().BeginIndex);
                        DoFunction(OldRange, KeywordIndex >= 0 && Runs[KeywordIndex]->GetRunInfo().Name == "SyntaxHighlight.FINLua.Keyword" && Keyword == "function");
						TSharedRef<IRun> NewRun = Runs[Runs.Num()-1];
						Runs.RemoveAt(Runs.Num()-1);
						Runs.Insert(NewRun, Index);
						DoOperator(FTextRange(Start, End), false);
						continue;
					}
				}
				if (TArray<FString>({" ","\t"}).Contains(TokenString)) {
					DoWhitespace(FTextRange(Start, End));
					continue;
				}
				if (TArray<FString>({".",",",":","(",")","[","]","{","}"}).Contains(TokenString)) {
					DoOperator(FTextRange(Start, End), false);
					continue;
				}
				if (TArray<FString>({"+","-","*","/","%","#","=","~","!",">","<"}).Contains(TokenString)) {
					DoOperator(FTextRange(Start, End), true);
					continue;
				}
			} else {
				if (!bIsNew) {
					FTextRange ModelRange = Run->GetTextRange();
					Runs.RemoveAt(Runs.Num()-1);
					DoNormal(ModelRange);
					bIsNew = false;
				} else if (TokenString.IsNumeric()) {
					bInNumber = true;
					StringStart = Start;
					StringEnd = End;
					continue;
				}
			}
			if (TokenString.IsNumeric()) DoNumber(FTextRange(Start, End));
			else DoNormal(FTextRange(Start, End));
		}
		
		if (bInNumber) {
			DoNumber(FTextRange(StringStart, StringEnd));
		} else if (bInString) {
			DoString(FTextRange(StringStart, StringEnd));
		} else if (bInLineComment || bInBlockComment) {
			DoComment(FTextRange(StringStart, StringEnd));
		}
		
		LinesToAdd.Emplace(MoveTemp(ModelString), MoveTemp(Runs));
	}
	TargetTextLayout.AddLines(LinesToAdd);
}

void SFINLuaCodeEditor::Construct(const FArguments& InArgs) {
	SyntaxHighlighter = FFINLuaSyntaxHighlighterTextLayoutMarshaller::Create(InArgs._Style);
	Style = InArgs._Style;

	HScrollBar = SNew(SScrollBar)
				.Style(&InArgs._Style->ScrollBarStyle)
				.Orientation(Orient_Horizontal)
				.Thickness(FVector2D(9.0f, 9.0f));

	VScrollBar = SNew(SScrollBar)
				.Style(&InArgs._Style->ScrollBarStyle)
				.Orientation(Orient_Vertical)
				.Thickness(FVector2D(9.0f, 9.0f));
	
	SBorder::Construct(SBorder::FArguments()
		.BorderImage(&Style->BorderImage)
		.BorderBackgroundColor(Style->BackgroundColor)
		.ForegroundColor(Style->ForegroundColor)
		.Padding(Style->Padding)[
			SNew(SHorizontalBox)
			+SHorizontalBox::Slot()
			.VAlign(VAlign_Fill)
			.HAlign(HAlign_Fill)
			.FillWidth(1)[
				SNew(SVerticalBox)
				+SVerticalBox::Slot()
				.VAlign(VAlign_Fill)
				.HAlign(HAlign_Fill)
				.FillHeight(1)[
					SAssignNew(TextEdit, SMultiLineEditableText)
					.AutoWrapText(false)
					.Margin(0.0f)
					.Marshaller(SyntaxHighlighter)
					.OnTextChanged(InArgs._OnTextChanged)
					.OnTextCommitted(InArgs._OnTextCommitted)
					.TextShapingMethod(ETextShapingMethod::Auto)
					.TextStyle(&InArgs._Style->NormalTextStyle)
					.HScrollBar(HScrollBar)
					.VScrollBar(VScrollBar)
					.CreateSlateTextLayout_Lambda([this](SWidget* InOwningWidget, const FTextBlockStyle& InDefaultTextStyle) {
						TextLayout = FSlateTextLayout::Create(InOwningWidget, InDefaultTextStyle);
						return TextLayout.ToSharedRef();
					})
				]
				+SVerticalBox::Slot()
				.AutoHeight()[
					SNew(SBox)
					.Padding(Style->HScrollBarPadding)[
						HScrollBar.ToSharedRef()
					]
				]
			]
			+SHorizontalBox::Slot()
			.AutoWidth()[
				SNew(SBox)
				.Padding(Style->VScrollBarPadding)[
					VScrollBar.ToSharedRef()
				]
			]
		]
	);
}

SFINLuaCodeEditor::SFINLuaCodeEditor() {}

int32 SFINLuaCodeEditor::OnPaint(const FPaintArgs& Args, const FGeometry& AllottedGeometry,	const FSlateRect& MyCullingRect, FSlateWindowElementList& OutDrawElements, int32 LayerId,	const FWidgetStyle& InWidgetStyle, bool bParentEnabled) const {
	FArrangedChildren ArrangedChildren(EVisibility::Visible);
	this->ArrangeChildren(AllottedGeometry, ArrangedChildren);

	if(ArrangedChildren.Num() > 0) {
		check( ArrangedChildren.Num() == 1);
		FArrangedWidget& TheChild = ArrangedChildren[0];

		int32 Layer = 0;
		Layer = TheChild.Widget->Paint( Args.WithNewParent(this), TheChild.Geometry, MyCullingRect, OutDrawElements, LayerId + 1, InWidgetStyle, ShouldBeEnabled( bParentEnabled ) );
	}
	
	float LineNumberWidth = FSlateApplication::Get().GetRenderer()->GetFontMeasureService()->Measure(FString::FromInt(TextLayout->GetLineViews().Num()), Style->LineNumberStyle.Font, 1).X;
	LineNumberWidth += 5.0;
	FGeometry CodeGeometry = AllottedGeometry.MakeChild(AllottedGeometry.GetLocalSize() - FVector2D(LineNumberWidth, 0), FSlateLayoutTransform(FVector2D(LineNumberWidth, 0)));
	FSlateRect CodeRect = MyCullingRect.ExtendBy(FMargin(LineNumberWidth, 0, 0, 0));

	const float InverseScale = Inverse(AllottedGeometry.Scale);
	int LineNumber = 0;
	OutDrawElements.PushClip(FSlateClippingZone(AllottedGeometry));
	for (const FTextLayout::FLineView& LineView : TextLayout->GetLineViews()) {
		++LineNumber;
		const FVector2D LocalLineOffset = LineView.Offset * InverseScale;
		const FSlateRect LineViewRect(AllottedGeometry.GetRenderBoundingRect(FSlateRect(LocalLineOffset * FVector2D(0, 1), LocalLineOffset + (LineView.Size * InverseScale))));
		if ( !FSlateRect::DoRectanglesIntersect(LineViewRect, MyCullingRect)) {
			continue;
		}

		FPaintGeometry LineGeo = AllottedGeometry.ToPaintGeometry(FSlateLayoutTransform(TransformPoint(InverseScale, LineView.Offset)));
		FSlateDrawElement::MakeText(OutDrawElements, LayerId++, LineGeo, FText::FromString(FString::FromInt(LineNumber)), Style->LineNumberStyle.Font, ESlateDrawEffect::None, Style->LineNumberStyle.ColorAndOpacity.GetColor(InWidgetStyle));
	}
	OutDrawElements.PopClip();
	
	return LayerId;
}

void SFINLuaCodeEditor::OnArrangeChildren(const FGeometry& AllottedGeometry, FArrangedChildren& ArrangedChildren) const {
	float LineNumberWidth = FSlateApplication::Get().GetRenderer()->GetFontMeasureService()->Measure(FString::FromInt(TextLayout->GetLineViews().Num()), Style->LineNumberStyle.Font, 1).X;
	LineNumberWidth += 5.0;
	FGeometry CodeGeo = AllottedGeometry.MakeChild(AllottedGeometry.Size - FVector2D(LineNumberWidth, 0), FSlateLayoutTransform(FVector2D(LineNumberWidth, 0)));
	ArrangeSingleChild(GSlateFlowDirection, CodeGeo, ArrangedChildren, ChildSlot, FVector2D(1));
}

void UFINLuaCodeEditor::HandleOnTextChanged(const FText& InText) {
	Text = InText;
	OnTextChanged.Broadcast(InText);
}

void UFINLuaCodeEditor::HandleOnTextCommitted(const FText& InText, ETextCommit::Type CommitMethod) {
	Text = InText;
	OnTextCommitted.Broadcast(InText, CommitMethod);
}

TSharedRef<SWidget> UFINLuaCodeEditor::RebuildWidget() {
	return SAssignNew(CodeEditor, SFINLuaCodeEditor)
		.Style(&Style)
		.OnTextChanged(BIND_UOBJECT_DELEGATE(FOnTextChanged, HandleOnTextChanged))
		.OnTextCommitted(BIND_UOBJECT_DELEGATE(FOnTextCommitted, HandleOnTextCommitted));
}

void UFINLuaCodeEditor::ReleaseSlateResources(bool bReleaseChildren) {
	CodeEditor.Reset();
}

void UFINLuaCodeEditor::SetIsReadOnly(bool bInReadOnly) {
	bReadOnly = bInReadOnly;
	if (CodeEditor) CodeEditor->TextEdit->SetIsReadOnly(bInReadOnly);
}

void UFINLuaCodeEditor::SetText(FText InText) {
	Text = InText;
	if (CodeEditor) CodeEditor->TextEdit->SetText(InText);
}

FText UFINLuaCodeEditor::GetText() const {
	return Text;
}

