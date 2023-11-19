﻿#include "FINUReflectionSource.h"

#include "FINArrayProperty.h"
#include "FINFuncProperty.h"
#include "FINReflection.h"
#include "FINStructProperty.h"
#include "FINUFunction.h"
#include "Buildables/FGBuildable.h"
#include "UObject/PropertyIterator.h"
#include "FicsItNetworks/FicsItNetworksModule.h"

TMap<UFunction*, UFINSignal*> UFINUReflectionSource::FuncSignalMap;

bool UFINUReflectionSource::ProvidesRequirements(UClass* Class) const {
	if (Class->IsChildOf(AFGBuildable::StaticClass())) return true;
	for (TFieldIterator<FProperty> Property(Class); Property; ++Property) {
		if (Property->GetName().StartsWith("netProp_")) return true;
		if (Property->GetName().StartsWith("netPropReadOnly_")) return true;
	}
	for (TFieldIterator<UFunction> Function(Class); Function; ++Function) {
		if (Function->GetName().StartsWith("netPropGet_")) return true;
		if (Function->GetName().StartsWith("netFunc_")) return true;
		if (Function->GetName().StartsWith("netSig_")) return true;
		if (Function->GetName() == "netDesc" && Cast<UTextProperty>(Function->GetReturnProperty()) && Function->ParmsSize == sizeof(FText)) return true;
	}
	return false;
}

bool UFINUReflectionSource::ProvidesRequirements(UScriptStruct* Struct) const {
	if (Struct->GetName().EndsWith("_NetType")) {
		return true;
	}
	return false;
}

void UFINUReflectionSource::FillData(FFINReflection* Ref, UFINClass* ToFillClass, UClass* Class) const {
	UFINClass* DirectParent = Ref->FindClass(Class->GetSuperClass(), false, false);
	if (DirectParent) {
		int childCount = 0;
		for(TObjectIterator<UClass> It; It; ++It) {
			if(It->IsChildOf(Class->GetSuperClass())) {
				childCount++;
			}
		}
		if (childCount < 2) {
			const_cast<TMap<UClass*, UFINClass*>*>(&Ref->GetClasses())->Remove(Class);
			ToFillClass = DirectParent;
		}
	}
	
	ToFillClass->InternalName = Class->GetName();
	ToFillClass->DisplayName = FText::FromString(ToFillClass->InternalName);

	FFINTypeMeta Meta = GetClassMeta(Class);

	if (Meta.InternalName.Len()) ToFillClass->InternalName = Meta.InternalName;
	if (!Meta.DisplayName.IsEmpty()) ToFillClass->DisplayName = Meta.DisplayName;
	if (!Meta.Description.IsEmpty()) ToFillClass->Description = Meta.Description;

	for (TFieldIterator<UFunction> Function(Class); Function; ++Function) {
		if (Function->GetOwnerClass() != Class) continue; 
		if (Function->GetName().StartsWith("netProp_")) {
			ToFillClass->Properties.Add(GenerateProperty(Ref, Meta, Class, *Function));
		}
	}
	for (TFieldIterator<UFunction> Func(Class); Func; ++Func) {
		if (Func->GetOwnerClass() != Class) continue; 
		if (Func->GetName().StartsWith("netPropGet_")) {
			ToFillClass->Properties.Add(GenerateProperty(Ref, Meta, Class, *Func));
		} else if (Func->GetName().StartsWith("netFunc_")) {
			ToFillClass->Functions.Add(GenerateFunction(Ref, Class, *Func));
		} else if (Func->GetName().StartsWith("netSig_")) {
			ToFillClass->Signals.Add(GenerateSignal(Ref, Class, *Func));
		} else if (Func->GetName() == "netDesc" && Cast<UTextProperty>(Func->GetReturnProperty()) && Func->ParmsSize == sizeof(FText)) {
			FText Desc;
			Class->GetDefaultObject()->ProcessEvent(*Func, &Desc);
			ToFillClass->Description = Desc;
		}
	}
	
	ToFillClass->Parent = Ref->FindClass(Class->GetSuperClass());
	if (ToFillClass->Parent == ToFillClass) ToFillClass->Parent = nullptr;
}

void UFINUReflectionSource::FillData(FFINReflection* Ref, UFINStruct* ToFillStruct, UScriptStruct* Struct) const {
	ToFillStruct->DisplayName = FText::FromString(Struct->GetName());
	ToFillStruct->InternalName = Struct->GetName();
	ToFillStruct->Description = FText::FromString("");
}

UFINUReflectionSource::FFINTypeMeta UFINUReflectionSource::GetClassMeta(UClass* Class) const {
	FFINTypeMeta Meta;

	Meta.InternalName = Class->GetName();
	Meta.DisplayName = FText::FromString(Meta.InternalName);

	// try tp get meta from buildable
	if (Class->IsChildOf(AFGBuildable::StaticClass())) {
		AFGBuildable* DefaultObj = Cast<AFGBuildable>(Class->GetDefaultObject());
		Meta.Description = DefaultObj->mDescription;
		Meta.DisplayName = DefaultObj->mDisplayName;
	}

	// try to get meta from function
	UFunction* MetaFunc = Class->FindFunctionByName("netClass_Meta");
	if (MetaFunc && MetaFunc->GetOuter() == Class) {
		// allocate parameter space
		uint8* Params = (uint8*)FMemory::Malloc(MetaFunc->PropertiesSize);
		FMemory::Memzero(Params + MetaFunc->ParmsSize, MetaFunc->PropertiesSize - MetaFunc->ParmsSize);
		MetaFunc->InitializeStruct(Params);
		bool bInvalidDeclaration = false;
		for (UProperty* LocalProp = MetaFunc->FirstPropertyToInit; LocalProp != NULL; LocalProp = (UProperty*)LocalProp->Next) {
			LocalProp->InitializeValue_InContainer(Params);
			if (!(LocalProp->PropertyFlags & CPF_OutParm)) bInvalidDeclaration = true;
		}

		if (!bInvalidDeclaration) {
			Class->GetDefaultObject()->ProcessEvent(MetaFunc, Params);

			for (TFieldIterator<UProperty> Property(MetaFunc); Property; ++Property) {
				UTextProperty* TextProp = Cast<UTextProperty>(*Property);
				UStrProperty* StrProp = Cast<UStrProperty>(*Property);
				UMapProperty* MapProp = Cast<UMapProperty>(*Property);
				if (StrProp && Property->GetName() == "InternalName") Meta.InternalName = StrProp->GetPropertyValue_InContainer(Params);
				else if (TextProp && Property->GetName() == "DisplayName") Meta.DisplayName = TextProp->GetPropertyValue_InContainer(Params);
				else if (TextProp && Property->GetName() == "Description") Meta.Description = TextProp->GetPropertyValue_InContainer(Params);
				else if (MapProp && Cast<UStrProperty>(MapProp->KeyProp)) {
					if (Cast<UStrProperty>(MapProp->ValueProp) && Property->GetName() == "PropertyInternalNames") {
						Meta.PropertyInternalNames = *MapProp->ContainerPtrToValuePtr<TMap<FString, FString>>(Params);
						Meta.PropertyDisplayNames.Empty();
						for (const TPair<FString, FString>& InternalName : Meta.PropertyInternalNames) {
							Meta.PropertyDisplayNames.Add(InternalName.Key, FText::FromString(InternalName.Value));
						}
					} else if (Cast<UTextProperty>(MapProp->ValueProp) && Property->GetName() == "PropertyDisplayNames") {
						for (const TPair<FString, FText>& DisplayName : *MapProp->ContainerPtrToValuePtr<TMap<FString, FText>>(Params)) {
							Meta.PropertyDisplayNames.FindOrAdd(DisplayName.Key) = DisplayName.Value;
						}
					} else if (Cast<UTextProperty>(MapProp->ValueProp) && Property->GetName() == "PropertyDescriptions") {
						for (const TPair<FString, FText>& Description : *MapProp->ContainerPtrToValuePtr<TMap<FString, FText>>(Params)) {
							Meta.PropertyDescriptions.FindOrAdd(Description.Key) = Description.Value;
						}
					} else if (Cast<UIntProperty>(MapProp->ValueProp) && Property->GetName() == "PropertyRuntimes") {
						for (const TPair<FString, int32>& Runtime : *MapProp->ContainerPtrToValuePtr<TMap<FString, int32>>(Params)) {
							Meta.PropertyRuntimes.FindOrAdd(Runtime.Key) = Runtime.Value;
						}
					}
				}
			}
		}
		
		for (UProperty* P = MetaFunc->DestructorLink; P; P = P->DestructorLinkNext) {
			if (!P->IsInContainer(MetaFunc->ParmsSize)) {
				P->DestroyValue_InContainer(Params);
			}
		}
		FMemory::Free(Params);
	}
	
	return Meta;
}

UFINUReflectionSource::FFINFunctionMeta UFINUReflectionSource::GetFunctionMeta(UClass* Class, UFunction* Func) const {
	FFINFunctionMeta Meta;

	// try to get meta from function
	UFunction* MetaFunc = Class->FindFunctionByName(*(FString("netFuncMeta_") + GetFunctionNameFromUFunction(Func)));
	if (MetaFunc) {
		// allocate parameter space
		uint8* Params = (uint8*)FMemory::Malloc(MetaFunc->PropertiesSize);
		FMemory::Memzero(Params + MetaFunc->ParmsSize, MetaFunc->PropertiesSize - MetaFunc->ParmsSize);
		MetaFunc->InitializeStruct(Params);
		bool bInvalidDeclaration = false;
		for (UProperty* LocalProp = MetaFunc->FirstPropertyToInit; LocalProp != NULL; LocalProp = (UProperty*)LocalProp->Next) {
			LocalProp->InitializeValue_InContainer(Params);
			if (!(LocalProp->PropertyFlags & CPF_OutParm)) bInvalidDeclaration = true;
		}

		if (!bInvalidDeclaration) {
			Class->GetDefaultObject()->ProcessEvent(MetaFunc, Params);

			for (TFieldIterator<UProperty> Property(MetaFunc); Property; ++Property) {
				UTextProperty* TextProp = Cast<UTextProperty>(*Property);
				UStrProperty* StrProp = Cast<UStrProperty>(*Property);
				UArrayProperty* ArrayProp = Cast<UArrayProperty>(*Property);
				UIntProperty* IntProp = Cast<UIntProperty>(*Property);
				if (StrProp && Property->GetName() == "InternalName") Meta.InternalName = StrProp->GetPropertyValue_InContainer(Params);
				else if (TextProp && Property->GetName() == "DisplayName") Meta.DisplayName = TextProp->GetPropertyValue_InContainer(Params);
				else if (TextProp && Property->GetName() == "Description") Meta.Description = TextProp->GetPropertyValue_InContainer(Params);
				else if (ArrayProp && Cast<UStrProperty>(ArrayProp->Inner) && Property->GetName() == "ParameterInternalNames") {
					Meta.ParameterInternalNames = *ArrayProp->ContainerPtrToValuePtr<TArray<FString>>(Params);
					Meta.ParameterDisplayNames.Empty();
					for (const FString& InternalName : Meta.ParameterInternalNames) {
						Meta.ParameterDisplayNames.Add(FText::FromString(InternalName));
					}
				} else if (ArrayProp && Cast<UTextProperty>(ArrayProp->Inner) && Property->GetName() == "ParameterDisplayNames") {
					int i = 0;
					for (const FText& DisplayName : *ArrayProp->ContainerPtrToValuePtr<TArray<FText>>(Params)) {
						if (Meta.ParameterDisplayNames.Num() > i) Meta.ParameterDisplayNames[i] = DisplayName;
						else Meta.ParameterDisplayNames.Add(DisplayName);
						++i;
					}
				} else if (ArrayProp && Cast<UTextProperty>(ArrayProp->Inner) && Property->GetName() == "ParameterDescriptions") {
					int i = 0;
					for (const FText& Description : *ArrayProp->ContainerPtrToValuePtr<TArray<FText>>(Params)) {
						if (Meta.ParameterDescriptions.Num() > i) Meta.ParameterDescriptions[i] = Description;
						else Meta.ParameterDescriptions.Add(Description);
						++i;
					}
				} else if (IntProp && Property->GetName() == "Runtime") Meta.Runtime = IntProp->GetPropertyValue_InContainer(Params);
			}
		}
	
		for (UProperty* P = MetaFunc->DestructorLink; P; P = P->DestructorLinkNext) {
			if (!P->IsInContainer(MetaFunc->ParmsSize)) {
				P->DestroyValue_InContainer(Params);
			}
		}
		FMemory::Free(Params);
	}

	return Meta;
}

UFINUReflectionSource::FFINSignalMeta UFINUReflectionSource::GetSignalMeta(UClass* Class, UFunction* Func) const {
	FFINSignalMeta Meta;

	// try to get meta from function
	UFunction* MetaFunc = Class->FindFunctionByName(*(FString("netSigMeta_") + GetSignalNameFromUFunction(Func)));
	if (MetaFunc) {
		// allocate parameter space
		uint8* Params = (uint8*)FMemory::Malloc(MetaFunc->PropertiesSize);
		FMemory::Memzero(Params + MetaFunc->ParmsSize, MetaFunc->PropertiesSize - MetaFunc->ParmsSize);
		MetaFunc->InitializeStruct(Params);
		bool bInvalidDeclaration = false;
		for (UProperty* LocalProp = MetaFunc->FirstPropertyToInit; LocalProp != NULL; LocalProp = (UProperty*)LocalProp->Next) {
			LocalProp->InitializeValue_InContainer(Params);
			if (!(LocalProp->PropertyFlags & CPF_OutParm)) bInvalidDeclaration = true;
		}

		if (!bInvalidDeclaration) {
			Class->GetDefaultObject()->ProcessEvent(MetaFunc, Params);

			for (TFieldIterator<UProperty> Property(MetaFunc); Property; ++Property) {
				UTextProperty* TextProp = Cast<UTextProperty>(*Property);
				UStrProperty* StrProp = Cast<UStrProperty>(*Property);
				UArrayProperty* ArrayProp = Cast<UArrayProperty>(*Property);
				if (StrProp && Property->GetName() == "InternalName") Meta.InternalName = StrProp->GetPropertyValue_InContainer(Params);
				else if (TextProp && Property->GetName() == "DisplayName") Meta.DisplayName = TextProp->GetPropertyValue_InContainer(Params);
				else if (TextProp && Property->GetName() == "Description") Meta.Description = TextProp->GetPropertyValue_InContainer(Params);
				else if (ArrayProp && Cast<UStrProperty>(ArrayProp->Inner) && Property->GetName() == "ParameterInternalNames") {
					Meta.ParameterInternalNames = *ArrayProp->ContainerPtrToValuePtr<TArray<FString>>(Params);
					Meta.ParameterDisplayNames.Empty();
					for (const FString& InternalName : Meta.ParameterInternalNames) {
						Meta.ParameterDisplayNames.Add(FText::FromString(InternalName));
					}
				} else if (ArrayProp && Cast<UTextProperty>(ArrayProp->Inner) && Property->GetName() == "ParameterDisplayNames") {
					int i = 0;
					for (const FText& DisplayName : *ArrayProp->ContainerPtrToValuePtr<TArray<FText>>(Params)) {
						if (Meta.ParameterDisplayNames.Num() > i) Meta.ParameterDisplayNames[i] = DisplayName;
						else Meta.ParameterDisplayNames.Add(DisplayName);
						++i;
					}
				} else if (ArrayProp && Cast<UTextProperty>(ArrayProp->Inner) && Property->GetName() == "ParameterDescriptions") {
					int i = 0;
					for (const FText& Description : *ArrayProp->ContainerPtrToValuePtr<TArray<FText>>(Params)) {
						if (Meta.ParameterDescriptions.Num() > i) Meta.ParameterDescriptions[i] = Description;
						else Meta.ParameterDescriptions.Add(Description);
						++i;
					}
				}
			}
		}
	
		for (UProperty* P = MetaFunc->DestructorLink; P; P = P->DestructorLinkNext) {
			if (!P->IsInContainer(MetaFunc->ParmsSize)) {
				P->DestroyValue_InContainer(Params);
			}
		}
		FMemory::Free(Params);
	}

	return Meta;
}

FString UFINUReflectionSource::GetFunctionNameFromUFunction(UFunction* Func) const {
	FString Name = Func->GetName();
	Name.RemoveFromStart("netFunc_");
	return Name;
}

FString UFINUReflectionSource::GetPropertyNameFromUFunction(UFunction* Func) const {
	FString Name = Func->GetName();
	if (!Name.RemoveFromStart("netPropGet_")) Name.RemoveFromStart("netPropSet_");
	return Name;
}

FString UFINUReflectionSource::GetPropertyNameFromUProperty(UProperty* Prop, bool& bReadOnly) const {
	FString Name = Prop->GetName();
	if (!Name.RemoveFromStart("netProp_")) bReadOnly = Name.RemoveFromStart("netPropReadOnly_");
	return Name;
}

FString UFINUReflectionSource::GetSignalNameFromUFunction(UFunction* Func) const {
	FString Name = Func->GetName();
	Name.RemoveFromStart("netSig_");
	return Name;
}

UFINFunction* UFINUReflectionSource::GenerateFunction(FFINReflection* Ref, UClass* Class, UFunction* Func) const {
	FFINFunctionMeta Meta = GetFunctionMeta(Class, Func);
	
	UFINUFunction* FINFunc = NewObject<UFINUFunction>(Ref->FindClass(Class, false, false));
	FINFunc->RefFunction = Func;
	FINFunc->InternalName = GetFunctionNameFromUFunction(Func);
	FINFunc->DisplayName = FText::FromString(FINFunc->InternalName);
	FINFunc->FunctionFlags = FIN_Func_MemberFunc;
	
	if (Meta.InternalName.Len()) FINFunc->InternalName = Meta.InternalName;
	if (!Meta.DisplayName.IsEmpty()) FINFunc->DisplayName = Meta.DisplayName;
	if (!Meta.Description.IsEmpty()) FINFunc->Description = Meta.Description;
	switch (Meta.Runtime) {
	case 0:
		FINFunc->FunctionFlags = (FINFunc->FunctionFlags & ~FIN_Func_Runtime) | FIN_Func_Sync;
		break;
	case 1:
		FINFunc->FunctionFlags = (FINFunc->FunctionFlags & ~FIN_Func_Runtime) | FIN_Func_Parallel;
		break;
	case 2:
		FINFunc->FunctionFlags = (FINFunc->FunctionFlags & ~FIN_Func_Runtime) | FIN_Func_Async;
		break;
	default:
		break;
	}
	for (TFieldIterator<UProperty> Param(Func); Param; ++Param) {
		if (!(Param->PropertyFlags & CPF_Parm)) continue;
		int i = FINFunc->Parameters.Num();
		UFINProperty* FINProp = FINCreateFINPropertyFromUProperty(*Param, FINFunc);
		FINProp->InternalName = Param->GetName();
		FINProp->DisplayName = FText::FromString(FINProp->InternalName);
		if (Meta.ParameterInternalNames.Num() > i) FINProp->InternalName = Meta.ParameterInternalNames[i];
		if (Meta.ParameterDisplayNames.Num() > i) FINProp->DisplayName = Meta.ParameterDisplayNames[i];
		if (Meta.ParameterDescriptions.Num() > i) FINProp->Description = Meta.ParameterDescriptions[i];
		FINProp->PropertyFlags = FINProp->PropertyFlags | FIN_Prop_Param;
		FINFunc->Parameters.Add(FINProp);
	}
	if (FINFunc->Parameters.Num() > 0) {
		UFINArrayProperty* Prop = nullptr;
		for (int i = FINFunc->Parameters.Num()-1; i >= 0; --i) {
			UFINArrayProperty* ArrProp = Cast<UFINArrayProperty>(FINFunc->Parameters[i]);
			if (ArrProp && !(ArrProp->GetPropertyFlags() & FIN_Prop_OutParam || ArrProp->GetPropertyFlags() & FIN_Prop_RetVal)) {
				Prop = ArrProp;
				break;
			}
		}
		if (Prop && UFINReflectionUtils::CheckIfVarargs(Prop)) {
			FINFunc->FunctionFlags = FINFunc->FunctionFlags | FIN_Func_VarArgs;
			FINFunc->VarArgsProperty = Prop;
			FINFunc->Parameters.Remove(Prop);
		}
	}
	return FINFunc;
}

UFINProperty* UFINUReflectionSource::GenerateProperty(FFINReflection* Ref, const FFINTypeMeta& Meta, UClass* Class, UProperty* Prop) const {
	UFINProperty* FINProp = FINCreateFINPropertyFromUProperty(Prop, Ref->FindClass(Class, false, false));
	FINProp->PropertyFlags = FINProp->PropertyFlags | FIN_Prop_Attrib;
	bool bReadOnly = false;
	FINProp->InternalName = GetPropertyNameFromUProperty(Prop, bReadOnly);
	if (bReadOnly) FINProp->PropertyFlags = FINProp->PropertyFlags | FIN_Prop_ReadOnly;
	if (Meta.PropertyInternalNames.Contains(FINProp->GetInternalName())) FINProp->InternalName = Meta.PropertyInternalNames[FINProp->GetInternalName()];
	if (Meta.PropertyDisplayNames.Contains(FINProp->GetInternalName())) FINProp->DisplayName = Meta.PropertyDisplayNames[FINProp->GetInternalName()];
	if (Meta.PropertyDescriptions.Contains(FINProp->GetInternalName())) FINProp->Description = Meta.PropertyDescriptions[FINProp->GetInternalName()];
	if (Meta.PropertyRuntimes.Contains(FINProp->GetInternalName())) {
		switch (Meta.PropertyRuntimes[FINProp->GetInternalName()]) {
		case 0:
			FINProp->PropertyFlags = (FINProp->PropertyFlags & ~FIN_Prop_Runtime) | FIN_Prop_Sync;
			break;
		case 1:
			FINProp->PropertyFlags = (FINProp->PropertyFlags & ~FIN_Prop_Runtime) | FIN_Prop_Parallel;
			break;
		case 2:
			FINProp->PropertyFlags = (FINProp->PropertyFlags & ~FIN_Prop_Runtime) | FIN_Prop_Async;
			break;
		default:
			break;
		}
	}
	return FINProp;
}

UFINProperty* UFINUReflectionSource::GenerateProperty(FFINReflection* Ref, const FFINTypeMeta& Meta, UClass* Class, UFunction* Get) const {
	UProperty* GetProp = nullptr;
	for (TFieldIterator<UProperty> Param(Get); Param; ++Param) {
		if (Param->PropertyFlags & CPF_Parm) {
			check(Param->PropertyFlags & CPF_OutParm);
			check(GetProp == nullptr);
			GetProp = *Param;
		}
	}
	UFINProperty* FINProp = FINCreateFINPropertyFromUProperty(GetProp, nullptr, Ref->FindClass(Class, false, false));
	FINProp->PropertyFlags = FINProp->PropertyFlags | FIN_Prop_Attrib;
	FINProp->InternalName = GetPropertyNameFromUFunction(Get);
	if (UFINFuncProperty* FINSProp = Cast<UFINFuncProperty>(FINProp)) {
		FINSProp->GetterFunc.Function = Get;
		FINSProp->GetterFunc.Property = FINCreateFINPropertyFromUProperty(GetProp, FINProp);
	}
	UFunction* Set = Class->FindFunctionByName(*(FString("netPropSet_") + FINProp->InternalName));
	if (Set) {
		UProperty* SetProp = nullptr;
		for (TFieldIterator<UProperty> Param(Set); Param; ++Param) {
			if (Param->PropertyFlags & CPF_Parm) {
				check(!(Param->PropertyFlags & CPF_OutParm));
				check(SetProp == nullptr);
				check(Param->GetClass() == GetProp->GetClass());
				SetProp = *Param;
			}
		}
		if (UFINFuncProperty* FINSProp = Cast<UFINFuncProperty>(FINProp)) {
			FINSProp->SetterFunc.Function = Set;
			FINSProp->SetterFunc.Property = FINCreateFINPropertyFromUProperty(SetProp, FINProp);
		}
	} else {
		FINProp->PropertyFlags = FINProp->PropertyFlags | FIN_Prop_ReadOnly;
	}
	if (Meta.PropertyInternalNames.Contains(FINProp->GetInternalName())) FINProp->InternalName = Meta.PropertyInternalNames[FINProp->GetInternalName()];
	if (Meta.PropertyDisplayNames.Contains(FINProp->GetInternalName())) FINProp->DisplayName = Meta.PropertyDisplayNames[FINProp->GetInternalName()];
	if (Meta.PropertyDescriptions.Contains(FINProp->GetInternalName())) FINProp->Description = Meta.PropertyDescriptions[FINProp->GetInternalName()];
	if (Meta.PropertyRuntimes.Contains(FINProp->GetInternalName())) {
		switch (Meta.PropertyRuntimes[FINProp->GetInternalName()]) {
		case 0:
			FINProp->PropertyFlags = (FINProp->PropertyFlags & ~FIN_Prop_Runtime) | FIN_Prop_Sync;
			break;
		case 1:
			FINProp->PropertyFlags = (FINProp->PropertyFlags & ~FIN_Prop_Runtime) | FIN_Prop_Parallel;
			break;
		case 2:
			FINProp->PropertyFlags = (FINProp->PropertyFlags & ~FIN_Prop_Runtime) | FIN_Prop_Async;
			break;
		default:
			break;
		}
	}
	
	return FINProp;
}

UFINSignal* UFINUReflectionSource::GenerateSignal(FFINReflection* Ref, UClass* Class, UFunction* Func) const {
	FFINSignalMeta Meta = GetSignalMeta(Class, Func);
	
	UFINSignal* FINSignal = NewObject<UFINSignal>(Ref->FindClass(Class, false, false));
	FINSignal->InternalName = GetSignalNameFromUFunction(Func);
	FINSignal->DisplayName = FText::FromString(FINSignal->InternalName);
	
	if (Meta.InternalName.Len()) FINSignal->InternalName = Meta.InternalName;
	if (!Meta.DisplayName.IsEmpty()) FINSignal->DisplayName = Meta.DisplayName;
	if (!Meta.Description.IsEmpty()) FINSignal->Description = Meta.Description;
	for (TFieldIterator<UProperty> Param(Func); Param; ++Param) {
		if (!(Param->PropertyFlags & CPF_Parm)) continue;
		int i = FINSignal->Parameters.Num();
		UFINProperty* FINProp = FINCreateFINPropertyFromUProperty(*Param, FINSignal);
		FINProp->InternalName = Param->GetName();
		FINProp->DisplayName = FText::FromString(FINProp->InternalName);
		if (Meta.ParameterInternalNames.Num() > i) FINProp->InternalName = Meta.ParameterInternalNames[i];
		if (Meta.ParameterDisplayNames.Num() > i) FINProp->DisplayName = Meta.ParameterDisplayNames[i];
		if (Meta.ParameterDescriptions.Num() > i) FINProp->Description = Meta.ParameterDescriptions[i];
		FINProp->PropertyFlags = FINProp->PropertyFlags | FIN_Prop_Param;
		FINSignal->Parameters.Add(FINProp);
	}
	if (FINSignal->Parameters.Num() > 0) {
		UFINArrayProperty* Prop = Cast<UFINArrayProperty>(FINSignal->Parameters[FINSignal->Parameters.Num()-1]);
		if (Prop && Prop->GetInternalName() == "varargs") {
			UFINStructProperty* Inner = Cast<UFINStructProperty>(Prop->InnerType);
			if (FINSignal && Inner->Property && Inner->Property->Struct == FFINAnyNetworkValue::StaticStruct()) {
				FINSignal->bIsVarArgs = true;
				FINSignal->Parameters.Pop();
			}
		}
	}
	FuncSignalMap.Add(Func, FINSignal);
	SetupFunctionAsSignal(Ref, Func);
	return FINSignal;
}

UFINSignal* UFINUReflectionSource::GetSignalFromFunction(UFunction* Func) {
	UFINSignal** Signal = FuncSignalMap.Find(Func);
	if (Signal) return *Signal;
	return nullptr;
}

void FINUFunctionBasedSignalExecute(UObject* Context, FFrame& Stack, RESULT_DECL) {
	// get signal name
	UFINSignal* FINSignal = UFINUReflectionSource::GetSignalFromFunction(Stack.CurrentNativeFunction);
	if (!FINSignal || !Context) {
		UE_LOG(LogFicsItNetworks, Log, TEXT("Invalid Unreal Reflection Signal Execution '%s'"), *Stack.CurrentNativeFunction->GetName());

		P_FINISH;
		
		return;
	}

	// allocate signal data storage and copy data
	void* ParamStruct = FMemory::Malloc(Stack.CurrentNativeFunction->PropertiesSize);
	FMemory::Memzero(((uint8*)ParamStruct) + Stack.CurrentNativeFunction->ParmsSize, Stack.CurrentNativeFunction->PropertiesSize - Stack.CurrentNativeFunction->ParmsSize);
	Stack.CurrentNativeFunction->InitializeStruct(ParamStruct);
	for (UProperty* LocalProp = Stack.CurrentNativeFunction->FirstPropertyToInit; LocalProp != NULL; LocalProp = (UProperty*)LocalProp->Next) {
		LocalProp->InitializeValue_InContainer(ParamStruct);
	}

	for (auto p = TFieldIterator<UProperty>(Stack.CurrentNativeFunction); p; ++p) {
		auto dp = p->ContainerPtrToValuePtr<void>(ParamStruct);
		if (Stack.Code) {
			std::invoke(&FFrame::Step, Stack, Context, dp);
		} else {
			Stack.StepExplicitProperty(dp, *p);
		}
	}

	// copy data into parameter list
	TArray<FFINAnyNetworkValue> Parameters;
	TArray<UFINProperty*> ParameterList = FINSignal->GetParameters();
	for (UFINProperty* Parameter : ParameterList) {
		Parameters.Add(Parameter->GetValue(ParamStruct));
	}
	if (FINSignal->bIsVarArgs && Parameters.Num() > 0 && Parameters.Last().GetType() == FIN_ARRAY) {
		FFINAnyNetworkValue Array = Parameters.Last();
		Parameters.Pop();
		Parameters.Append(Array.GetArray());
	}

	// destroy parameter struct
	for (UProperty* P = Stack.CurrentNativeFunction->DestructorLink; P; P = P->DestructorLinkNext) {
		if (!P->IsInContainer(Stack.CurrentNativeFunction->ParmsSize)) {
			P->DestroyValue_InContainer(ParamStruct);
		}
	}
	FMemory::Free(ParamStruct);

	FINSignal->Trigger(Context, Parameters);

	P_FINISH;
}

void UFINUReflectionSource::SetupFunctionAsSignal(FFINReflection* Ref, UFunction* Func) const {
	Func->SetNativeFunc(&FINUFunctionBasedSignalExecute);
	Func->FunctionFlags |= FUNC_Native;
}
