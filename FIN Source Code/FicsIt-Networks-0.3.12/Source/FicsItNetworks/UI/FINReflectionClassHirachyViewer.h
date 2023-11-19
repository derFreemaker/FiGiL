﻿#pragma once

#include "FINReflectionUIStyle.h"
#include "SlateBasics.h"
#include "FINReflectionUIContext.h"

class SFINReflectionClassHirachyViewer : public SCompoundWidget {
	SLATE_BEGIN_ARGS(SFINReflectionClassHirachyViewer) :
        _Style(&FFINReflectionUIStyleStruct::GetDefault()) {}
		SLATE_ATTRIBUTE(const FFINReflectionUIStyleStruct*, Style)
	SLATE_END_ARGS()
public:
	void Construct(const FArguments& InArgs, const TSharedPtr<FFINReflectionUIStruct>& SearchStruct, FFINReflectionUIContext* Context);
private:
	FFINReflectionUIContext* Context = nullptr;
	TAttribute<const FFINReflectionUIStyleStruct*> Style;
	TSharedPtr<FFINReflectionUIStruct> SearchStruct;
	TArray<TSharedPtr<FFINReflectionUIStruct>> StructSource;
};
