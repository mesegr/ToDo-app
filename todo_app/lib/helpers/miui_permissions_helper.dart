import 'package:flutter/material.dart';

class MiuiPermissionsHelper {
  static Future<void> showMiuiInstructions(BuildContext context) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange[300]),
                const SizedBox(width: 12),
                const Text('Configuración MIUI Requerida'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Para que las alarmas funcionen en MIUI, debes configurar:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    '1',
                    'Desactivar Ahorro de Batería',
                    'Configuración > Aplicaciones > Administrar aplicaciones > Todo App > Ahorro de batería > Sin restricciones',
                  ),
                  const SizedBox(height: 12),
                  _buildStep(
                    '2',
                    'Activar Inicio Automático',
                    'Configuración > Aplicaciones > Administrar aplicaciones > Todo App > Inicio automático > Activar',
                  ),
                  const SizedBox(height: 12),
                  _buildStep(
                    '3',
                    'Bloquear en Recientes',
                    'Abre Aplicaciones Recientes > Mantén presionada la app > Toca el candado 🔒',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF8B5CF6),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sin estos permisos, MIUI cancelará tus alarmas',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  static Widget _buildStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF8B5CF6),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
