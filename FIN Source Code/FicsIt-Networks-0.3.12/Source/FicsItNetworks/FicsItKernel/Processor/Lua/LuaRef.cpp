﻿#include "LuaRef.h"

#include "LuaFuture.h"
#include "LuaProcessor.h"
#include "LuaProcessorStateStorage.h"
#include "FicsItNetworks/Reflection/FINFunction.h"
#include "FicsItNetworks/Reflection/FINStruct.h"

namespace FicsItKernel {
	namespace Lua {
		int luaCallFINFunc(lua_State* L, UFINFunction* Func, const FFINExecutionContext& Ctx, const std::string& typeName) {
			// get input parameters from lua stack
			TArray<FINAny> Input;
			int args = lua_gettop(L);
			int paramsLoaded = 2;
			for (UFINProperty* Param : Func->GetParameters()) {
				if (Param->GetPropertyFlags() & FIN_Prop_Param && !(Param->GetPropertyFlags() & (FIN_Prop_OutParam | FIN_Prop_RetVal))) {
					FINAny NewParam = luaToProperty(L, Param, paramsLoaded++);
					Input.Add(MoveTemp(NewParam));
				}
			}
			for (; paramsLoaded <= args; ++paramsLoaded) {
				FINAny Param;
				luaToNetworkValue(L, paramsLoaded, Param);
				Input.Add(MoveTemp(Param));
			}
			args = 0;

			// sync tick if necessary
			const EFINFunctionFlags FuncFlags = Func->GetFunctionFlags();
			// ReSharper disable once CppEntityAssignedButNoRead
			// ReSharper disable once CppJoinDeclarationAndAssignment
			TSharedPtr<FLuaSyncCall> SyncCall;
			bool bRunDirectly = false;
			if (FuncFlags & FIN_Func_RT_Async) {
				bRunDirectly = true;
			} else if (FuncFlags & FIN_Func_RT_Parallel) {
				SyncCall = MakeShared<FLuaSyncCall>(L);
				bRunDirectly = true;
			} else {
				luaFuture(L, FFINFutureReflection(Func, Ctx, Input));
				args = 1;
			}

			if (bRunDirectly) {
				TArray<FINAny> Output;
				try {
					Output = Func->Execute(Ctx, Input);
				} catch (const FFINFunctionBadArgumentException& Ex) {
					return luaL_argerror(L, Ex.ArgumentIndex+2, TCHAR_TO_UTF8(*Ex.GetMessage()));
				} catch (const FFINReflectionException& Ex) {
					return luaL_error(L, TCHAR_TO_UTF8(*Ex.GetMessage()));
				}

				// push output onto lua stack
				for (const FINAny& Value : Output) {
					networkValueToLua(L, Value, Ctx.GetTrace());
					++args;
				}
			}
			
			return UFINLuaProcessor::luaAPIReturn(L, args);
		}

		int luaFindGetMember(lua_State* L, UFINStruct* Struct, const FFINExecutionContext& Ctx, const FString& MemberName, const FString& MetaName, int(*callFunc)(lua_State*), bool classInstance) {
			// get cache function
			luaL_getmetafield(L, 1, LUA_REF_CACHE);																// Instance, FuncName, InstanceCache
			
			if (lua_getfield(L, -1, TCHAR_TO_UTF8(*MetaName)) != LUA_TNIL)  {										// Instance, FuncName, InstanceCache, CachedFunc
				return UFINLuaProcessor::luaAPIReturn(L, 1);
			}																											// Instance, FuncName, InstanceCache, nil

			// try to find property
			UFINProperty* Property = Struct->FindFINProperty(MemberName, classInstance ? FIN_Prop_ClassProp : FIN_Prop_Attrib);
			if (Property) {
				// ReSharper disable once CppEntityAssignedButNoRead
				// ReSharper disable once CppJoinDeclarationAndAssignment
				TSharedPtr<FLuaSyncCall> SyncCall;
				if (!(Property->GetPropertyFlags() & FIN_Prop_RT_Async)) SyncCall = MakeShared<FLuaSyncCall>(L);
				
				networkValueToLua(L, Property->GetValue(Ctx), Ctx.GetTrace());
				return UFINLuaProcessor::luaAPIReturn(L, 1);
			}

			// try to find function
			UFINFunction* Function = Struct->FindFINFunction(MemberName, classInstance ? FIN_Func_ClassFunc : FIN_Func_MemberFunc);
			if (Function) {
				LuaRefFuncData* Func = static_cast<LuaRefFuncData*>(lua_newuserdata(L, sizeof(LuaRefFuncData)));
				new (Func) LuaRefFuncData{Struct, Function};
				luaL_setmetatable(L, LUA_REF_FUNC_DATA);
				lua_pushcclosure(L, callFunc, 1);
				lua_pushvalue(L, -1);
				lua_setfield(L, 3, TCHAR_TO_UTF8(*MetaName));
				return UFINLuaProcessor::luaAPIReturn(L, 1);
			}
			
			return UFINLuaProcessor::luaAPIReturn(L, 0);
		}

		int luaFindSetMember(lua_State* L, UFINStruct* Struct, const FFINExecutionContext& Ctx, const FString& MemberName, bool classInstance) {
			// try to find property
			UFINProperty* Property = Struct->FindFINProperty(MemberName, classInstance ? FIN_Prop_ClassProp : FIN_Prop_Attrib);
			if (Property) {
				// ReSharper disable once CppEntityAssignedButNoRead
				// ReSharper disable once CppJoinDeclarationAndAssignment
				FINAny Value = luaToProperty(L, Property, 3);
				
				TSharedPtr<FLuaSyncCall> SyncCall;
				EFINRepPropertyFlags PropFlags = Property->GetPropertyFlags();
				bool bRunDirectly = false;
				if (PropFlags & FIN_Prop_RT_Async) {
					bRunDirectly = true;
				} else if (PropFlags & FIN_Prop_RT_Parallel) {
					SyncCall = MakeShared<FLuaSyncCall>(L);
					bRunDirectly = true;
				} else {
					luaFuture(L, FFINFutureReflection(Property, Ctx, {Value}));
				}
				
				if (bRunDirectly) Property->SetValue(Ctx, Value);
				
				return UFINLuaProcessor::luaAPIReturn(L, 1);
			}
			
			return luaL_argerror(L, 2, TCHAR_TO_UTF8(*("No property with name '" + MemberName + "' found")));
		}

		int luaRefFuncDataUnpersist(lua_State* L) {
			UFINLuaProcessor* Processor = UFINLuaProcessor::luaGetProcessor(L);
			
			// get persist storage
			FFINLuaProcessorStateStorage& Storage = Processor->StateStorage;

			// get class
			UFINStruct* Struct = Cast<UFINStruct>(Storage.GetRef(luaL_checkinteger(L, lua_upvalueindex(1))));
			UFINFunction* Function = Cast<UFINFunction>(Storage.GetRef(luaL_checkinteger(L, lua_upvalueindex(2))));

			// create value
			LuaRefFuncData* Func = static_cast<LuaRefFuncData*>(lua_newuserdata(L, sizeof(LuaRefFuncData)));
			new (Func) LuaRefFuncData();
			Func->Struct = Struct;
			Func->Func = Function;
			luaL_setmetatable(L, LUA_REF_FUNC_DATA);
			
			return 1;
		}

		int luaRefFuncDataPersist(lua_State* L) {
			LuaRefFuncData* Func = static_cast<LuaRefFuncData*>(luaL_checkudata(L, 1, LUA_REF_FUNC_DATA));

			UFINLuaProcessor* Processor = UFINLuaProcessor::luaGetProcessor(L);
			
			// get persist storage
			FFINLuaProcessorStateStorage& Storage = Processor->StateStorage;

			// push type name to persist
			lua_pushinteger(L, Storage.Add(Func->Struct));
			lua_pushinteger(L, Storage.Add(Func->Func));
			
			// create & return closure
			lua_pushcclosure(L, &luaRefFuncDataUnpersist, 2);
			return 1;
		}

		int luaRefFuncDataGC(lua_State* L) {
			LuaRefFuncData* Func = static_cast<LuaRefFuncData*>(luaL_checkudata(L, 1, LUA_REF_FUNC_DATA));
			Func->~LuaRefFuncData();
			return 0;
		}

		static const luaL_Reg luaRefFuncDataLib[] = {
			{"__persist", luaRefFuncDataPersist},
			{"__gc", luaRefFuncDataGC},
			{nullptr, nullptr}
		};

		void setupRefUtils(lua_State* L) {
			PersistSetup("RefUtils", -2);
		
			luaL_newmetatable(L, LUA_REF_FUNC_DATA);
			luaL_setfuncs(L, luaRefFuncDataLib, 0);
			lua_pop(L, 1);
		
			lua_pushcfunction(L, luaRefFuncDataUnpersist);			// ..., LuaInstanceUnpersist
			PersistValue("RefFuncDataUnpersist");					// ...
		}
	}
}
