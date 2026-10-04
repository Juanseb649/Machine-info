#define COBJMACROS
#include "win_utils.h"

#include <oleauto.h>
#include <wbemidl.h>
#include <stdio.h>

#include "../../../domain/models.h"

typedef struct {
    const wchar_t *wmi_namespace;
    const wchar_t *query;
    const wchar_t *value_property;
    const wchar_t *critical_property;
    double scale;
    const char *source;
} thermal_query;

static const thermal_query QUERIES[] = {
    {L"ROOT\\CIMV2",
     L"SELECT Name, Temperature FROM Win32_PerfFormattedData_Counters_ThermalZoneInformation",
     L"Temperature", NULL, 1.0, "wmi_perf"},
    {L"ROOT\\WMI",
     L"SELECT InstanceName, CurrentTemperature, CriticalTripPoint FROM MSAcpi_ThermalZoneTemperature",
     L"CurrentTemperature", L"CriticalTripPoint", 10.0, "wmi_acpi"},
};

static int variant_to_double(VARIANT *v, double *out)
{
    VARIANT converted;
    VariantInit(&converted);
    if (FAILED(VariantChangeType(&converted, v, 0, VT_R8))) return 0;
    *out = converted.dblVal;
    VariantClear(&converted);
    return 1;
}

static double kelvin_to_celsius(double raw, double scale)
{
    return raw / scale - 273.15;
}

static HRESULT run_query(IWbemLocator *locator, const thermal_query *q, mi_temperature_list *out)
{
    IWbemServices *services = NULL;
    BSTR ns = SysAllocString(q->wmi_namespace);
    HRESULT hr = IWbemLocator_ConnectServer(locator, ns, NULL, NULL, NULL, 0, NULL, NULL, &services);
    SysFreeString(ns);
    if (FAILED(hr)) return hr;

    CoSetProxyBlanket((IUnknown *)services, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, NULL,
                      RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE, NULL, EOAC_NONE);

    IEnumWbemClassObject *enumerator = NULL;
    BSTR language = SysAllocString(L"WQL");
    BSTR query = SysAllocString(q->query);
    hr = IWbemServices_ExecQuery(services, language, query,
                                 WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY, NULL, &enumerator);
    SysFreeString(language);
    SysFreeString(query);

    if (SUCCEEDED(hr)) {
        IWbemClassObject *row = NULL;
        ULONG returned = 0;
        while (IEnumWbemClassObject_Next(enumerator, 2000, 1, &row, &returned) == WBEM_S_NO_ERROR && returned) {
            VARIANT value, name, critical;
            VariantInit(&value);
            VariantInit(&name);
            VariantInit(&critical);

            double raw = 0;
            if (SUCCEEDED(IWbemClassObject_Get(row, q->value_property, 0, &value, NULL, NULL)) &&
                variant_to_double(&value, &raw) && raw > 0) {
                mi_temperature *t = mi_temperature_list_push(out);
                if (t) {
                    t->celsius = kelvin_to_celsius(raw, q->scale);
                    mi_copy_str(t->source, sizeof(t->source), q->source);
                    if (SUCCEEDED(IWbemClassObject_Get(row, L"Name", 0, &name, NULL, NULL)) && name.vt == VT_BSTR)
                        mi_wide_to_utf8(name.bstrVal, t->label, sizeof(t->label));
                    else if (SUCCEEDED(IWbemClassObject_Get(row, L"InstanceName", 0, &name, NULL, NULL)) && name.vt == VT_BSTR)
                        mi_wide_to_utf8(name.bstrVal, t->label, sizeof(t->label));
                    else
                        snprintf(t->label, sizeof(t->label), "Thermal zone %u", (unsigned)out->count);

                    double crit = 0;
                    if (q->critical_property &&
                        SUCCEEDED(IWbemClassObject_Get(row, q->critical_property, 0, &critical, NULL, NULL)) &&
                        variant_to_double(&critical, &crit) && crit > 0)
                        t->critical_celsius = kelvin_to_celsius(crit, q->scale);
                }
            }
            VariantClear(&value);
            VariantClear(&name);
            VariantClear(&critical);
            IWbemClassObject_Release(row);
        }
        IEnumWbemClassObject_Release(enumerator);
    }
    IWbemServices_Release(services);
    return hr;
}

mi_status mi_windows_read_thermal_zones(mi_temperature_list *out)
{
    HRESULT init = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    int owns_com = SUCCEEDED(init);
    if (FAILED(init) && init != RPC_E_CHANGED_MODE) return MI_ERR_UNSUPPORTED;

    CoInitializeSecurity(NULL, -1, NULL, NULL, RPC_C_AUTHN_LEVEL_DEFAULT,
                         RPC_C_IMP_LEVEL_IMPERSONATE, NULL, EOAC_NONE, NULL);

    IWbemLocator *locator = NULL;
    HRESULT hr = CoCreateInstance(&CLSID_WbemLocator, NULL, CLSCTX_INPROC_SERVER, &IID_IWbemLocator, (void **)&locator);
    int denied = 0;
    if (SUCCEEDED(hr)) {
        for (size_t i = 0; i < sizeof(QUERIES) / sizeof(QUERIES[0]) && out->count == 0; i++) {
            HRESULT q = run_query(locator, &QUERIES[i], out);
            if (q == (HRESULT)WBEM_E_ACCESS_DENIED || q == E_ACCESSDENIED) denied = 1;
        }
        IWbemLocator_Release(locator);
    }

    if (owns_com) CoUninitialize();
    if (out->count > 0) return MI_OK;
    return denied ? MI_ERR_PERMISSION : MI_ERR_UNSUPPORTED;
}
