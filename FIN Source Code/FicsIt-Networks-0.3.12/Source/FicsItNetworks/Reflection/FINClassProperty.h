﻿#pragma once

#include "FINFuncProperty.h"
#include "FINClassProperty.generated.h"

UCLASS(BlueprintType)
class FICSITNETWORKS_API UFINClassProperty : public UFINFuncProperty {
	GENERATED_BODY()
public:
	UPROPERTY()
	UClassProperty* Property = nullptr;
	UPROPERTY()
	UClass* Subclass = nullptr;

	// Begin UFINProperty
	virtual FINAny GetValue(const FFINExecutionContext& Ctx) const override {
		if (Property) return FWeakObjectPtr(Property->GetPropertyValue_InContainer(Ctx.GetGeneric()));
		return Super::GetValue(Ctx);
	}
	
	virtual void SetValue(const FFINExecutionContext& Ctx, const FINAny& Value) const override {
		UClass* Class = nullptr;
		if (Value.GetType() == FIN_CLASS) Class = Value.GetClass();
		else if (Value.GetType() == FIN_OBJ) Class = Cast<UClass>(Value.GetObj().Get());
		else if (Class) return;
		if (Class && GetSubclass() && !Class->IsChildOf(GetSubclass())) return;
		if (Property) Property->SetPropertyValue_InContainer(Ctx.GetGeneric(), Class);
		else Super::SetValue(Ctx, Value);
	}

	virtual TEnumAsByte<EFINNetworkValueType> GetType() const { return FIN_CLASS; }
	// End UFINProperty

	/**
	 * Returns the subclass which all values need to be child of (or equal to)
	 * if they want to set the value.
	 * Nullptr if any class is allows
	 */
	virtual UClass* GetSubclass() const {
		if (Subclass) return Subclass;
		if (Property) return Property->PropertyClass;
		return nullptr;
	}
};
