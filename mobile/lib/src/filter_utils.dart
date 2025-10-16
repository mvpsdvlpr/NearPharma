/// Helper utilities for filter state management.
/// Provides pure functions that can be unit tested without widgets.

Map<String, dynamic> resetFiltersForFechaChange(Map<String, dynamic> current) {
  // current may contain keys: regionSeleccionada, comunaSeleccionada, comunas, farmacias, error
  return {
    'regionSeleccionada': null,
    'comunaSeleccionada': null,
    'comunas': <dynamic>[],
    'farmacias': <dynamic>[],
    'error': null,
  };
}
