import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// -------------------------------------------------------------
// CREDENCIALES DE SUPABASE
// -------------------------------------------------------------
const String supabaseUrl = 'https://jgwcndehkoumpcddanyo.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impnd2NuZGVoa291bXBjZGRhbnlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE5NDAxNDIsImV4cCI6MjEwNzUxNjE0Mn0.dCgeBm8bL5Z8zqK3LwGnxscQ1eBt7O9TdG6cQ19diOI';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  runApp(const MiAppMercado());
}

// -------------------------------------------------------------
// HELPER PARA SUBIR IMÁGENES A STORAGE
// -------------------------------------------------------------
Future<String?> subirImagenASupabase(String rutaLocal, String carpeta) async {
  if (!File(rutaLocal).existsSync()) return null;
  try {
    final file = File(rutaLocal);
    final ext = rutaLocal.split('.').last;
    final nombreArchivo =
        '$carpeta/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await supabase.storage.from('imagenes_productos').upload(
          nombreArchivo,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    final url =
        supabase.storage.from('imagenes_productos').getPublicUrl(nombreArchivo);
    return url;
  } catch (e) {
    debugPrint('Error subiendo imagen a Supabase Storage: $e');
    return null;
  }
}

// -------------------------------------------------------------
// WIDGET HELPER PARA MOSTRAR IMAGENES (WEB / LOCAL / FALLBACK)
// -------------------------------------------------------------
Widget widgetImagenCargada(
  String? ruta, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
  IconData iconoVacio = Icons.shopping_bag_outlined,
}) {
  if (ruta == null || ruta.isEmpty) {
    return Icon(iconoVacio, size: (height != null ? height * 0.4 : 32));
  }
  if (ruta.startsWith('http://') || ruta.startsWith('https://')) {
    return Image.network(
      ruta,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.broken_image_outlined, size: (height != null ? height * 0.4 : 32)),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: height,
          width: width,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
  if (File(ruta).existsSync()) {
    return Image.file(
      File(ruta),
      height: height,
      width: width,
      fit: fit,
    );
  }
  return Icon(iconoVacio, size: (height != null ? height * 0.4 : 32));
}

// -------------------------------------------------------------
// MODELOS DE DATOS
// -------------------------------------------------------------

class Producto {
  final String id;
  final String idVendedor;
  final String nombreTiendaVendedor;
  final String usuarioVendedor;
  final String nombre;
  final String descripcion;
  final double precio;
  int stock;
  final String ubicacion;
  final bool disponibleInmediato;
  final String entregaEstimada;
  final String metodoPago;
  final String datosTarjeta;
  final String? rutaFoto;
  bool activo;

  Producto({
    required this.id,
    required this.idVendedor,
    required this.nombreTiendaVendedor,
    required this.usuarioVendedor,
    required this.nombre,
    this.descripcion = '',
    required this.precio,
    required this.stock,
    required this.ubicacion,
    this.disponibleInmediato = true,
    this.entregaEstimada = 'Inmediata',
    required this.metodoPago,
    this.datosTarjeta = '',
    this.rutaFoto,
    this.activo = true,
  });

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'id_vendedor': idVendedor,
        'nombre_tienda_vendedor': nombreTiendaVendedor,
        'usuario_vendedor': usuarioVendedor,
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'stock': stock,
        'ubicacion': ubicacion,
        'disponible_inmediato': disponibleInmediato,
        'entrega_estimada': entregaEstimada,
        'metodo_pago': metodoPago,
        'datos_tarjeta': datosTarjeta,
        'ruta_foto': rutaFoto,
        'activo': activo,
      };

  factory Producto.fromSupabaseMap(Map<String, dynamic> map) => Producto(
        id: map['id'] ?? '',
        idVendedor: map['id_vendedor'] ?? 'admin',
        nombreTiendaVendedor:
            map['nombre_tienda_vendedor'] ?? 'Tienda del Vendedor',
        usuarioVendedor: map['usuario_vendedor'] ?? 'vendedor',
        nombre: map['nombre'] ?? '',
        descripcion: map['descripcion'] ?? '',
        precio: (map['precio'] as num).toDouble(),
        stock: map['stock'] ?? 0,
        ubicacion: map['ubicacion'] ?? '',
        disponibleInmediato: map['disponible_inmediato'] ?? true,
        entregaEstimada: map['entrega_estimada'] ?? 'Inmediata',
        metodoPago: map['metodo_pago'] ?? 'Ambas',
        datosTarjeta: map['datos_tarjeta'] ?? '',
        rutaFoto: map['ruta_foto'],
        activo: map['activo'] ?? true,
      );
}

class SolicitudCambioEntrega {
  final String id;
  final String folioApartado;
  final String idVendedor;
  final String nombreProducto;
  String nuevaUbicacion;
  String nuevaHora;
  String notaCliente;
  String estado;
  String motivoRespuesta;

  SolicitudCambioEntrega({
    required this.id,
    required this.folioApartado,
    required this.idVendedor,
    required this.nombreProducto,
    required this.nuevaUbicacion,
    required this.nuevaHora,
    this.notaCliente = '',
    this.estado = 'pendiente',
    this.motivoRespuesta = '',
  });

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'folio_apartado': folioApartado,
        'id_vendedor': idVendedor,
        'nombre_producto': nombreProducto,
        'nueva_ubicacion': nuevaUbicacion,
        'nueva_hora': nuevaHora,
        'nota_cliente': notaCliente,
        'estado': estado,
        'motivo_respuesta': motivoRespuesta,
      };

  factory SolicitudCambioEntrega.fromSupabaseMap(Map<String, dynamic> map) =>
      SolicitudCambioEntrega(
        id: map['id'] ?? '',
        folioApartado: map['folio_apartado'] ?? '',
        idVendedor: map['id_vendedor'] ?? '',
        nombreProducto: map['nombre_producto'] ?? '',
        nuevaUbicacion: map['nueva_ubicacion'] ?? '',
        nuevaHora: map['nueva_hora'] ?? '',
        notaCliente: map['nota_cliente'] ?? '',
        estado: map['estado'] ?? 'pendiente',
        motivoRespuesta: map['motivo_respuesta'] ?? '',
      );
}

class VentaRegistro {
  final String folio;
  final String idVendedor;
  final String nombreProducto;
  final double precio;
  final DateTime fecha;

  VentaRegistro({
    required this.folio,
    required this.idVendedor,
    required this.nombreProducto,
    required this.precio,
    required this.fecha,
  });

  Map<String, dynamic> toSupabaseMap() => {
        'folio': folio,
        'id_vendedor': idVendedor,
        'nombre_producto': nombreProducto,
        'precio': precio,
        'fecha': fecha.toIso8601String(),
      };

  factory VentaRegistro.fromSupabaseMap(Map<String, dynamic> map) =>
      VentaRegistro(
        folio: map['folio'] ?? '',
        idVendedor: map['id_vendedor'] ?? 'admin',
        nombreProducto: map['nombre_producto'] ?? '',
        precio: (map['precio'] as num).toDouble(),
        fecha: DateTime.parse(map['fecha']),
      );
}

class Vendedor {
  final String id;
  final String usuario;
  final String contrasena;
  String nombreTienda;
  String descripcionTienda;
  String? fotoPerfil;

  Vendedor({
    required this.id,
    required this.usuario,
    required this.contrasena,
    required this.nombreTienda,
    this.descripcionTienda =
        '¡Bienvenido a nuestra tienda! Calidad y entrega rápida en campus.',
    this.fotoPerfil,
  });

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'usuario': usuario,
        'contrasena': contrasena,
        'nombre_tienda': nombreTienda,
        'descripcion_tienda': descripcionTienda,
        'foto_perfil': fotoPerfil,
      };

  factory Vendedor.fromSupabaseMap(Map<String, dynamic> map) => Vendedor(
        id: map['id'] ?? '',
        usuario: map['usuario'] ?? '',
        contrasena: map['contrasena'] ?? '',
        nombreTienda: map['nombre_tienda'] ?? '',
        descripcionTienda: map['descripcion_tienda'] ??
            '¡Bienvenido a nuestra tienda! Calidad y entrega rápida en campus.',
        fotoPerfil: map['foto_perfil'],
      );
}

// -------------------------------------------------------------
// APLICACIÓN PRINCIPAL Y TEMA
// -------------------------------------------------------------

class MiAppMercado extends StatelessWidget {
  const MiAppMercado({super.key});

  @override
  Widget build(BuildContext context) {
    const Color colorPrimario = Color(0xFF003B73);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mercado Local',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorPrimario,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: colorPrimario,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorPrimario,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: colorPrimario,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const PantallaPrincipalContenedor(),
    );
  }
}

// -------------------------------------------------------------
// CONTENEDOR PRINCIPAL CONECTADO A SUPABASE
// -------------------------------------------------------------

class PantallaPrincipalContenedor extends StatefulWidget {
  const PantallaPrincipalContenedor({super.key});

  @override
  State<PantallaPrincipalContenedor> createState() =>
      _PantallaPrincipalContenedorState();
}

class _PantallaPrincipalContenedorState
    extends State<PantallaPrincipalContenedor> {
  int _indiceActual = 0;
  List<Producto> _productos = [];
  List<VentaRegistro> _ventas = [];
  List<Vendedor> _vendedores = [];
  List<SolicitudCambioEntrega> _solicitudes = [];
  Vendedor? _vendedorSesion;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _iniciarSuscripcionesEnTiempoReal();
  }

  void _iniciarSuscripcionesEnTiempoReal() {
    supabase
        .from('productos')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen((datos) {
          if (mounted) {
            setState(() {
              _productos =
                  datos.map((map) => Producto.fromSupabaseMap(map)).toList();
            });
          }
        });

    supabase
        .from('vendedores')
        .stream(primaryKey: ['id'])
        .listen((datos) {
          if (mounted) {
            setState(() {
              _vendedores =
                  datos.map((map) => Vendedor.fromSupabaseMap(map)).toList();
              if (_vendedorSesion != null) {
                _vendedorSesion = _vendedores.firstWhere(
                  (v) => v.id == _vendedorSesion!.id,
                  orElse: () => _vendedorSesion!,
                );
              }
            });
          }
        });

    supabase
        .from('solicitudes_cambio')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen((datos) {
          if (mounted) {
            setState(() {
              _solicitudes = datos
                  .map((map) => SolicitudCambioEntrega.fromSupabaseMap(map))
                  .toList();
            });
          }
        });

    supabase
        .from('ventas_registro')
        .stream(primaryKey: ['id'])
        .order('fecha', ascending: false)
        .listen((datos) {
          if (mounted) {
            setState(() {
              _ventas = datos
                  .map((map) => VentaRegistro.fromSupabaseMap(map))
                  .toList();
            });
          }
        });

    _comprobarSesionLocal();
  }

  Future<void> _comprobarSesionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final guardadoId = prefs.getString('vendedor_sesion_id');
    if (guardadoId != null) {
      try {
        final res = await supabase
            .from('vendedores')
            .select()
            .eq('id', guardadoId)
            .maybeSingle();
        if (res != null) {
          _vendedorSesion = Vendedor.fromSupabaseMap(res);
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _cargando = false;
      });
    }
  }

  Future<void> _apartarProducto(Producto prod) async {
    if (prod.stock > 0 && prod.activo) {
      final nuevoStock = prod.stock - 1;
      await supabase
          .from('productos')
          .update({'stock': nuevoStock}).eq('id', prod.id);

      final folio = 'FOL-${DateTime.now().millisecondsSinceEpoch % 1000000}';
      final qrData = jsonEncode({
        'folio': folio,
        'idProducto': prod.id,
        'idVendedor': prod.idVendedor,
        'nombre': prod.nombre,
        'precio': prod.precio,
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => DialogoComprobanteQR(
          folio: folio,
          nombreProducto: prod.nombre,
          precio: prod.precio,
          qrPayload: qrData,
          onSolicitarCambio: () {
            Navigator.pop(ctx);
            _mostrarDialogoSolicitudCambio(
              folio: folio,
              idVendedor: prod.idVendedor,
              nombreProducto: prod.nombre,
            );
          },
        ),
      );
    }
  }

  void _mostrarDialogoSolicitudCambio({
    required String folio,
    required String idVendedor,
    required String nombreProducto,
    SolicitudCambioEntrega? solicitudPrevia,
  }) {
    final ctrlUbicacion =
        TextEditingController(text: solicitudPrevia?.nuevaUbicacion ?? '');
    final ctrlHora =
        TextEditingController(text: solicitudPrevia?.nuevaHora ?? '');
    final ctrlNota =
        TextEditingController(text: solicitudPrevia?.notaCliente ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(solicitudPrevia != null
            ? 'Proponer Nueva Opción'
            : 'Cambio de Lugar u Hora'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Folio: $folio',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Producto: $nombreProducto',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrlUbicacion,
                decoration: const InputDecoration(
                  labelText: 'Nueva ubicación propuesta *',
                  hintText: 'Ej. Biblioteca central, Entrada 3',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrlHora,
                decoration: const InputDecoration(
                  labelText: 'Nueva hora propuesta *',
                  hintText: 'Ej. 2:30 PM, Mañana a las 11:00 AM',
                  prefixIcon: Icon(Icons.access_time),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrlNota,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mensaje para el vendedor (Opcional)',
                  hintText: 'Ej. Salgo de clase a esa hora',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final ubi = ctrlUbicacion.text.trim();
              final hora = ctrlHora.text.trim();
              if (ubi.isEmpty || hora.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor indica la nueva ubicación y hora'),
                  ),
                );
                return;
              }

              if (solicitudPrevia != null) {
                await supabase.from('solicitudes_cambio').update({
                  'nueva_ubicacion': ubi,
                  'nueva_hora': hora,
                  'nota_cliente': ctrlNota.text.trim(),
                  'estado': 'pendiente',
                  'motivo_respuesta': '',
                }).eq('id', solicitudPrevia.id);
              } else {
                final nuevaSol = SolicitudCambioEntrega(
                  id: 'sol_${DateTime.now().millisecondsSinceEpoch}',
                  folioApartado: folio,
                  idVendedor: idVendedor,
                  nombreProducto: nombreProducto,
                  nuevaUbicacion: ubi,
                  nuevaHora: hora,
                  notaCliente: ctrlNota.text.trim(),
                  estado: 'pendiente',
                );
                await supabase
                    .from('solicitudes_cambio')
                    .insert(nuevaSol.toSupabaseMap());
              }

              if (!mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Solicitud enviada al vendedor!'),
                  backgroundColor: Colors.blueAccent,
                ),
              );
            },
            child: const Text('Enviar Solicitud'),
          ),
        ],
      ),
    );
  }

  Future<void> _responderSolicitud(
      String idSolicitud, bool aceptar, String motivo) async {
    await supabase.from('solicitudes_cambio').update({
      'estado': aceptar ? 'aceptada' : 'rechazada',
      'motivo_respuesta': motivo,
    }).eq('id', idSolicitud);
  }

  Future<void> _ajustarStockRapido(String idProducto, int delta) async {
    final index = _productos.indexWhere((p) => p.id == idProducto);
    if (index >= 0) {
      final nuevoStock = _productos[index].stock + delta;
      if (nuevoStock >= 0) {
        await supabase
            .from('productos')
            .update({'stock': nuevoStock}).eq('id', idProducto);
      }
    }
  }

  Future<void> _actualizarPerfilVendedor(Vendedor vActualizado) async {
    await supabase
        .from('vendedores')
        .update(vActualizado.toSupabaseMap())
        .eq('id', vActualizado.id);

    await supabase.from('productos').update({
      'nombre_tienda_vendedor': vActualizado.nombreTienda,
      'usuario_vendedor': vActualizado.usuario,
    }).eq('id_vendedor', vActualizado.id);
  }

  void _verPerfilPublicoVendedor(String idVendedor) {
    final vendedor = _vendedores.firstWhere(
      (v) => v.id == idVendedor,
      orElse: () => Vendedor(
        id: idVendedor,
        usuario: 'vendedor',
        contrasena: '',
        nombreTienda: 'Tienda del Vendedor',
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => PantallaPerfilTiendaPublico(
          vendedor: vendedor,
          productos: _productos,
          onApartar: _apartarProducto,
        ),
      ),
    );
  }

  Future<void> _registrarNuevoVendedor(
      String nombre, String usuario, String contrasena) async {
    final nuevo = Vendedor(
      id: 'vend_${DateTime.now().millisecondsSinceEpoch}',
      nombreTienda: nombre,
      usuario: usuario,
      contrasena: contrasena,
    );

    await supabase.from('vendedores').insert(nuevo.toSupabaseMap());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vendedor_sesion_id', nuevo.id);

    setState(() {
      _vendedorSesion = nuevo;
    });
  }

  Future<void> _iniciarSesion(Vendedor v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vendedor_sesion_id', v.id);
    setState(() {
      _vendedorSesion = v;
    });
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vendedor_sesion_id');
    setState(() {
      _vendedorSesion = null;
    });
  }

  Future<void> _guardarOEditarProducto(Producto producto) async {
    await supabase.from('productos').upsert(producto.toSupabaseMap());
  }

  Future<void> _eliminarProducto(String id) async {
    await supabase.from('productos').delete().eq('id', id);
  }

  Future<void> _cambiarEstadoProducto(String id, bool nuevoEstado) async {
    await supabase
        .from('productos')
        .update({'activo': nuevoEstado}).eq('id', id);
  }

  Future<void> _cambiarEstadoTodos(String idVendedor, bool activar) async {
    await supabase
        .from('productos')
        .update({'activo': activar}).eq('id_vendedor', idVendedor);
  }

  Future<void> _registrarEntregaExitosa(VentaRegistro venta) async {
    await supabase.from('ventas_registro').insert(venta.toSupabaseMap());
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> pantallas = [
      PantallaCatalogo(
        productos: _productos,
        solicitudes: _solicitudes,
        vendedores: _vendedores,
        onApartar: _apartarProducto,
        onVerPerfilTienda: _verPerfilPublicoVendedor,
        onReintentarSolicitud: (sol) {
          _mostrarDialogoSolicitudCambio(
            folio: sol.folioApartado,
            idVendedor: sol.idVendedor,
            nombreProducto: sol.nombreProducto,
            solicitudPrevia: sol,
          );
        },
      ),
      _vendedorSesion == null
          ? PantallaAuthVendedor(
              vendedores: _vendedores,
              onLogin: _iniciarSesion,
              onRegister: _registrarNuevoVendedor,
            )
          : PanelVendedor(
              vendedorActual: _vendedorSesion!,
              productos: _productos,
              ventas: _ventas,
              solicitudes: _solicitudes,
              onCerrarSesion: _cerrarSesion,
              onGuardarProducto: _guardarOEditarProducto,
              onEliminarProducto: _eliminarProducto,
              onCambiarEstado: _cambiarEstadoProducto,
              onCambiarEstadoTodos: _cambiarEstadoTodos,
              onAjustarStock: _ajustarStockRapido,
              onActualizarPerfil: _actualizarPerfilVendedor,
              onRegistrarEntrega: _registrarEntregaExitosa,
              onResponderSolicitud: _responderSolicitud,
            ),
    ];

    return Scaffold(
      body: pantallas[_indiceActual],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: (idx) => setState(() => _indiceActual = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Vendedor',
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// CATÁLOGO CON ENLACE AL PERFIL DE LA TIENDA
// -------------------------------------------------------------

class PantallaCatalogo extends StatefulWidget {
  final List<Producto> productos;
  final List<SolicitudCambioEntrega> solicitudes;
  final List<Vendedor> vendedores;
  final Function(Producto) onApartar;
  final Function(String idVendedor) onVerPerfilTienda;
  final Function(SolicitudCambioEntrega) onReintentarSolicitud;

  const PantallaCatalogo({
    super.key,
    required this.productos,
    required this.solicitudes,
    required this.vendedores,
    required this.onApartar,
    required this.onVerPerfilTienda,
    required this.onReintentarSolicitud,
  });

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  String _busqueda = '';
  String _filtroPago = 'Todos';

  void _verMisSolicitudes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Mis Peticiones de Cambio de Entrega',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: widget.solicitudes.isEmpty
                        ? const Center(
                            child: Text(
                              'Aún no has solicitado cambios de hora o ubicación.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            controller: controller,
                            itemCount: widget.solicitudes.length,
                            itemBuilder: (c, i) {
                              final sol = widget.solicitudes[i];
                              Color colorEstado = Colors.amber.shade800;
                              String textoEstado = 'Pendiente de respuesta';
                              IconData iconoEstado = Icons.hourglass_top;

                              if (sol.estado == 'aceptada') {
                                colorEstado = Colors.green;
                                textoEstado = '¡Aceptada por el vendedor!';
                                iconoEstado = Icons.check_circle;
                              } else if (sol.estado == 'rechazada') {
                                colorEstado = Colors.redAccent;
                                textoEstado = 'No es posible para el vendedor';
                                iconoEstado = Icons.cancel;
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            sol.nombreProducto,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15),
                                          ),
                                          Chip(
                                            avatar: Icon(iconoEstado,
                                                size: 16, color: colorEstado),
                                            label: Text(
                                              textoEstado,
                                              style: TextStyle(
                                                color: colorEstado,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                            backgroundColor:
                                                colorEstado.withValues(alpha: 0.1),
                                          ),
                                        ],
                                      ),
                                      Text('Folio: ${sol.folioApartado}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                      const SizedBox(height: 6),
                                      Text(
                                          '📍 Propuesta: ${sol.nuevaUbicacion}'),
                                      Text('⏰ Hora: ${sol.nuevaHora}'),
                                      if (sol.estado == 'rechazada') ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            sol.motivoRespuesta.isNotEmpty
                                                ? 'Motivo del vendedor: "${sol.motivoRespuesta}"\nPor favor propone otro horario o ubicación.'
                                                : 'El vendedor no puede en este punto/horario.',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.edit_calendar),
                                            label: const Text(
                                                'Proponer otra hora / lugar'),
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              widget.onReintentarSolicitud(sol);
                                            },
                                          ),
                                        ),
                                      ],
                                      if (sol.estado == 'aceptada') ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            '✓ El vendedor te esperará en el punto y hora acordados.',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prodsFiltrados = widget.productos.where((p) {
      if (!p.activo) return false;
      final coincideNombre =
          p.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          p.descripcion.toLowerCase().contains(_busqueda.toLowerCase()) ||
          p.nombreTiendaVendedor.toLowerCase().contains(_busqueda.toLowerCase()) ||
          p.usuarioVendedor.toLowerCase().contains(_busqueda.toLowerCase());
      final coincidePago = _filtroPago == 'Todos' ||
          p.metodoPago == _filtroPago ||
          p.metodoPago == 'Ambas';
      return coincideNombre && coincidePago;
    }).toList();

    final tiendasCoincidentes = _busqueda.trim().isNotEmpty
        ? widget.vendedores.where((v) =>
            v.nombreTienda.toLowerCase().contains(_busqueda.toLowerCase()) ||
            v.usuario.toLowerCase().contains(_busqueda.toLowerCase())).toList()
        : <Vendedor>[];

    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pending_actions_outlined),
            tooltip: 'Mis Peticiones de Entrega',
            onPressed: _verMisSolicitudes,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar por producto, tienda o vendedor...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => setState(() => _busqueda = val),
                ),
                if (tiendasCoincidentes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: tiendasCoincidentes.length,
                      itemBuilder: (ctx, i) {
                        final t = tiendasCoincidentes[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ActionChip(
                            avatar: const Icon(Icons.store, size: 16),
                            label: Text('Ver tienda: ${t.nombreTienda}'),
                            onPressed: () => widget.onVerPerfilTienda(t.id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Todos', 'Efectivo', 'Tarjeta'].map((pago) {
                      final sel = _filtroPago == pago;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(pago),
                          selected: sel,
                          onSelected: (_) =>
                              setState(() => _filtroPago = pago),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: prodsFiltrados.isEmpty
                ? const Center(
                    child: Text('No hay productos disponibles en este momento'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: prodsFiltrados.length,
                    itemBuilder: (ctx, idx) {
                      final prod = prodsFiltrados[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (prod.rutaFoto != null && prod.rutaFoto!.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16)),
                                child: widgetImagenCargada(
                                  prod.rutaFoto,
                                  height: 190,
                                  width: double.infinity,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => widget
                                        .onVerPerfilTienda(prod.idVendedor),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.storefront,
                                            size: 18,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Tienda: ${prod.nombreTiendaVendedor}  |  Vendedor: ${prod.usuarioVendedor}',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                          ),
                                          const Icon(Icons.arrow_forward_ios,
                                              size: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          prod.nombre,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '\$${prod.precio.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (prod.descripcion.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      prod.descripcion,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: esOscuro
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Chip(
                                        label: Text(
                                          'Disponibles: ${prod.stock}',
                                          style: TextStyle(
                                            color: prod.stock > 0
                                                ? (esOscuro
                                                    ? Colors.greenAccent.shade200
                                                    : Colors.green.shade800)
                                                : (esOscuro
                                                    ? Colors.redAccent.shade200
                                                    : Colors.red.shade800),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        backgroundColor: prod.stock > 0
                                            ? (esOscuro
                                                ? Colors.green.withValues(alpha: 0.2)
                                                : Colors.green.shade50)
                                            : (esOscuro
                                                ? Colors.red.withValues(alpha: 0.2)
                                                : Colors.red.shade50),
                                        side: BorderSide(
                                          color: prod.stock > 0
                                              ? (esOscuro
                                                  ? Colors.greenAccent.shade400
                                                  : Colors.green.shade200)
                                              : (esOscuro
                                                  ? Colors.redAccent.shade400
                                                  : Colors.red.shade200),
                                          width: 0.8,
                                        ),
                                      ),
                                      Chip(
                                        avatar: Icon(
                                          prod.disponibleInmediato
                                              ? Icons.flash_on
                                              : Icons.timelapse,
                                          size: 16,
                                          color: prod.disponibleInmediato
                                              ? Colors.amber.shade700
                                              : Colors.blueAccent,
                                        ),
                                        label: Text(
                                          prod.disponibleInmediato
                                              ? 'Disponibilidad Inmediata'
                                              : 'Bajo Pedido / Encargo',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_filled_outlined,
                                        size: 17,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Entrega estimada: ${prod.entregaEstimada}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          prod.ubicacion,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (prod.datosTarjeta.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Datos de pago: ${prod.datosTarjeta}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      icon: const Icon(Icons.qr_code),
                                      onPressed: prod.stock > 0
                                          ? () => widget.onApartar(prod)
                                          : null,
                                      label: Text(prod.stock > 0
                                          ? 'Apartar y Obtener QR'
                                          : 'Agotado'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// PANTALLA PÚBLICA DEL PERFIL DE LA TIENDA
// -------------------------------------------------------------

class PantallaPerfilTiendaPublico extends StatelessWidget {
  final Vendedor vendedor;
  final List<Producto> productos;
  final Function(Producto) onApartar;

  const PantallaPerfilTiendaPublico({
    super.key,
    required this.vendedor,
    required this.productos,
    required this.onApartar,
  });

  @override
  Widget build(BuildContext context) {
    final prodsVendedor = productos
        .where((p) => p.idVendedor == vendedor.id && p.activo)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(vendedor.nombreTienda),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: ClipOval(
                      child: widgetImagenCargada(
                        vendedor.fotoPerfil,
                        height: 92,
                        width: 92,
                        iconoVacio: Icons.storefront,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    vendedor.nombreTienda,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vendedor: ${vendedor.usuario}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    vendedor.descripcionTienda,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Productos disponibles (${prodsVendedor.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            prodsVendedor.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('Esta tienda no tiene productos disponibles.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: prodsVendedor.length,
                    itemBuilder: (ctx, i) {
                      final prod = prodsVendedor[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: widgetImagenCargada(
                              prod.rutaFoto,
                              width: 50,
                              height: 50,
                            ),
                          ),
                          title: Text(prod.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '\$${prod.precio.toStringAsFixed(2)} | Stock: ${prod.stock}'),
                          trailing: FilledButton(
                            onPressed: prod.stock > 0
                                ? () => onApartar(prod)
                                : null,
                            child: Text(prod.stock > 0 ? 'Apartar' : 'Agotado'),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// COMPROBANTE QR CON RECOMENDACIÓN DE SCREENSHOT
// -------------------------------------------------------------

class DialogoComprobanteQR extends StatelessWidget {
  final String folio;
  final String nombreProducto;
  final double precio;
  final String qrPayload;
  final VoidCallback onSolicitarCambio;

  const DialogoComprobanteQR({
    super.key,
    required this.folio,
    required this.nombreProducto,
    required this.precio,
    required this.qrPayload,
    required this.onSolicitarCambio,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Center(
        child: Text(
          '¡Apartado Exitoso!',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      content: SizedBox(
        width: 290,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:MainAxisSize.min,
            children: [
              Text(
                'Folio: $folio',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                nombreProducto,
                style: const TextStyle(fontSize: 15),
                textAlign: TextAlign.center,
              ),
              Text(
                '\$${precio.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),

              // AVISO DESTACADO DE SCREENSHOT
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade700, width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        size: 20, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se recomienda tomar screenshot para que lo valide el vendedor',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Container(
                width: 210,
                height: 210,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 188.0,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Muestra este código al vendedor para recoger tu producto.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text('Pedir cambio de lugar/hora',
                    style: TextStyle(fontSize: 13)),
                onPressed: onSolicitarCambio,
              ),
            ],
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// AUTENTICACIÓN / REGISTRO
// -------------------------------------------------------------

class PantallaAuthVendedor extends StatefulWidget {
  final List<Vendedor> vendedores;
  final Function(Vendedor) onLogin;
  final Function(String nombre, String usuario, String pass) onRegister;

  const PantallaAuthVendedor({
    super.key,
    required this.vendedores,
    required this.onLogin,
    required this.onRegister,
  });

  @override
  State<PantallaAuthVendedor> createState() => _PantallaAuthVendedorState();
}

class _PantallaAuthVendedorState extends State<PantallaAuthVendedor> {
  bool _esRegistro = false;
  final _ctrlNombre = TextEditingController();
  final _ctrlUsuario = TextEditingController();
  final _ctrlPass = TextEditingController();

  void _enviar() {
    final usuario = _ctrlUsuario.text.trim();
    final pass = _ctrlPass.text.trim();

    if (usuario.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    if (_esRegistro) {
      final nombre = _ctrlNombre.text.trim();
      if (nombre.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa el nombre de tu tienda')),
        );
        return;
      }
      final yaExiste = widget.vendedores
          .any((v) => v.usuario.toLowerCase() == usuario.toLowerCase());
      if (yaExiste) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ese nombre de usuario ya está en uso')),
        );
        return;
      }
      widget.onRegister(nombre, usuario, pass);
    } else {
      final encontrado = widget.vendedores.firstWhere(
        (v) =>
            v.usuario.toLowerCase() == usuario.toLowerCase() &&
            v.contrasena == pass,
        orElse: () =>
            Vendedor(id: '', usuario: '', contrasena: '', nombreTienda: ''),
      );
      if (encontrado.id.isNotEmpty) {
        widget.onLogin(encontrado);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario o contraseña incorrectos')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esRegistro ? 'Registrar Tienda' : 'Acceso Vendedor'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.store_mall_directory_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _esRegistro ? 'Crea tu cuenta de vendedor' : 'Iniciar Sesión',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  if (_esRegistro) ...[
                    TextField(
                      controller: _ctrlNombre,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de tu puesto o tienda',
                        prefixIcon: Icon(Icons.store),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _ctrlUsuario,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ctrlPass,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _enviar,
                      child: Text(_esRegistro ? 'Registrarse' : 'Ingresar'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _esRegistro = !_esRegistro),
                    child: Text(_esRegistro
                        ? '¿Ya tienes cuenta? Inicia sesión'
                        : '¿Nuevo vendedor? Regístrate aquí'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// PANEL DE VENDEDOR
// -------------------------------------------------------------

class PanelVendedor extends StatelessWidget {
  final Vendedor vendedorActual;
  final List<Producto> productos;
  final List<VentaRegistro> ventas;
  final List<SolicitudCambioEntrega> solicitudes;
  final VoidCallback onCerrarSesion;
  final Function(Producto) onGuardarProducto;
  final Function(String) onEliminarProducto;
  final Function(String id, bool estado) onCambiarEstado;
  final Function(String idVendedor, bool activar) onCambiarEstadoTodos;
  final Function(String idProducto, int delta) onAjustarStock;
  final Function(Vendedor v) onActualizarPerfil;
  final Function(VentaRegistro) onRegistrarEntrega;
  final Function(String idSolicitud, bool aceptar, String motivo)
      onResponderSolicitud;

  const PanelVendedor({
    super.key,
    required this.vendedorActual,
    required this.productos,
    required this.ventas,
    required this.solicitudes,
    required this.onCerrarSesion,
    required this.onGuardarProducto,
    required this.onEliminarProducto,
    required this.onCambiarEstado,
    required this.onCambiarEstadoTodos,
    required this.onAjustarStock,
    required this.onActualizarPerfil,
    required this.onRegistrarEntrega,
    required this.onResponderSolicitud,
  });

  void _dialogoRechazo(BuildContext context, String idSolicitud) {
    final ctrlMotivo = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar cambio propuesto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indícale al cliente el motivo:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrlMotivo,
              decoration: const InputDecoration(
                hintText: 'Ej. No puedo a esa hora, tengo clases',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              final motivo = ctrlMotivo.text.trim();
              onResponderSolicitud(idSolicitud, false, motivo);
              Navigator.pop(ctx);
            },
            child: const Text('Confirmar Rechazo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productosDelVendedor =
        productos.where((p) => p.idVendedor == vendedorActual.id).toList();

    final ventasDelVendedor =
        ventas.where((v) => v.idVendedor == vendedorActual.id).toList();

    final solicitudesDelVendedor =
        solicitudes.where((s) => s.idVendedor == vendedorActual.id).toList();

    final pendientesCount = solicitudesDelVendedor
        .where((s) => s.estado == 'pendiente')
        .length;

    final totalCobrado =
        ventasDelVendedor.fold(0.0, (acc, v) => acc + v.precio);

    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(vendedorActual.nombreTienda),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: onCerrarSesion,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            indicatorWeight: 3.5,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: [
              const Tab(
                  icon: Icon(Icons.inventory_2_outlined), text: 'Inventario'),
              Tab(
                icon: Badge(
                  isLabelVisible: pendientesCount > 0,
                  label: Text('$pendientesCount'),
                  child: const Icon(Icons.swap_horiz_outlined),
                ),
                text: 'Peticiones',
              ),
              const Tab(
                  icon: Icon(Icons.history_outlined), text: 'Entregas'),
              const Tab(
                  icon: Icon(Icons.account_circle_outlined), text: 'Mi Perfil'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // PESTAÑA 1: INVENTARIO
            Column(
              children: [
                if (productosDelVendedor.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: esOscuro
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Control general:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(Icons.visibility_off, size: 16),
                          label: const Text('Pausar todos',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            onCambiarEstadoTodos(vendedorActual.id, false);
                          },
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('Activar todos',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            onCambiarEstadoTodos(vendedorActual.id, true);
                          },
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: productosDelVendedor.isEmpty
                      ? const Center(
                          child: Text('Aún no tienes productos publicados'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: productosDelVendedor.length,
                          itemBuilder: (ctx, idx) {
                            final prod = productosDelVendedor[idx];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: widgetImagenCargada(
                                          prod.rutaFoto,
                                          width: 50,
                                          height: 50,
                                        ),
                                      ),
                                      title: Text(
                                        prod.nombre,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: prod.activo
                                              ? null
                                              : Colors.grey,
                                          decoration: prod.activo
                                              ? null
                                              : TextDecoration.lineThrough,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '\$${prod.precio.toStringAsFixed(2)} | Ubicación: ${prod.ubicacion}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blueAccent),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (c) =>
                                                      FormularioProducto(
                                                    vendedorActual:
                                                        vendedorActual,
                                                    productoEditar: prod,
                                                    onGuardar:
                                                        onGuardarProducto,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent),
                                            onPressed: () =>
                                                onEliminarProducto(prod.id),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'Stock:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton.filledTonal(
                                              iconSize: 16,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32),
                                              icon: const Icon(Icons.remove),
                                              onPressed: prod.stock > 0
                                                  ? () => onAjustarStock(
                                                      prod.id, -1)
                                                  : null,
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8.0),
                                              child: Text(
                                                '${prod.stock}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                            ),
                                            IconButton.filledTonal(
                                              iconSize: 16,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32),
                                              icon: const Icon(Icons.add),
                                              onPressed: () =>
                                                  onAjustarStock(prod.id, 1),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              prod.activo
                                                  ? 'Visible'
                                                  : 'Pausado',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: prod.activo
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                            Transform.scale(
                                              scale: 0.8,
                                              child: Switch(
                                                value: prod.activo,
                                                activeThumbColor: Colors.green,
                                                onChanged: (val) {
                                                  onCambiarEstado(prod.id, val);
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),

            // PESTAÑA 2: PETICIONES
            solicitudesDelVendedor.isEmpty
                ? const Center(
                    child: Text('No hay solicitudes de cambio de entrega'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: solicitudesDelVendedor.length,
                    itemBuilder: (ctx, idx) {
                      final sol = solicitudesDelVendedor[idx];
                      final esPendiente = sol.estado == 'pendiente';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      sol.nombreProducto,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      sol.estado.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: sol.estado == 'aceptada'
                                            ? Colors.green
                                            : (sol.estado == 'rechazada'
                                                ? Colors.red
                                                : Colors.orange),
                                      ),
                                    ),
                                    backgroundColor: (sol.estado == 'aceptada'
                                            ? Colors.green
                                            : (sol.estado == 'rechazada'
                                                ? Colors.red
                                                : Colors.orange))
                                        .withValues(alpha: 0.1),
                                  ),
                                ],
                              ),
                              Text('Folio comprobante: ${sol.folioApartado}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.place,
                                      size: 18, color: Colors.blueAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Nueva Ubicación: ${sol.nuevaUbicacion}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      size: 18, color: Colors.orangeAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Nueva Hora solicitada: ${sol.nuevaHora}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              if (sol.notaCliente.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Nota del cliente: "${sol.notaCliente}"',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              if (esPendiente) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(
                                              color: Colors.redAccent),
                                        ),
                                        icon: const Icon(Icons.close),
                                        label: const Text('No puedo'),
                                        onPressed: () =>
                                            _dialogoRechazo(context, sol.id),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Aceptar'),
                                        onPressed: () {
                                          onResponderSolicitud(
                                              sol.id, true, '');
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (sol.estado == 'rechazada' &&
                                  sol.motivoRespuesta.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Motivo enviado al cliente: ${sol.motivoRespuesta}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            // PESTAÑA 3: ENTREGAS Y BALANCE
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Escanear QR Entrega'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: esOscuro
                                ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                : Colors.deepPurple.shade50,
                            foregroundColor: esOscuro
                                ? Colors.white
                                : Colors.deepPurple,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => PantallaEscaner(
                                  idVendedor: vendedorActual.id,
                                  onValidado: (folio, nom, precio) {
                                    final yaEntregado = ventasDelVendedor
                                        .any((v) => v.folio == folio);
                                    if (yaEntregado) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('¡ALERTA! Este folio ya fue validado anteriormente.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    onRegistrarEntrega(
                                      VentaRegistro(
                                        folio: folio,
                                        idVendedor: vendedorActual.id,
                                        nombreProducto: nom,
                                        precio: precio,
                                        fecha: DateTime.now(),
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('¡Entrega validada! Folio: $folio'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: esOscuro
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Cobrado Acumulado:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${totalCobrado.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ventasDelVendedor.isEmpty
                      ? const Center(
                          child: Text('Sin entregas completadas aún'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: ventasDelVendedor.length,
                          itemBuilder: (ctx, idx) {
                            final reg = ventasDelVendedor[idx];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.check_circle,
                                    color: Colors.green),
                                title: Text(reg.nombreProducto),
                                subtitle: Text('Folio: ${reg.folio}'),
                                trailing: Text(
                                  '+\$${reg.precio.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),

            // PESTAÑA 4: MI PERFIL DE TIENDA
            VistaEditarPerfilTienda(
              vendedor: vendedorActual,
              onGuardarPerfil: onActualizarPerfil,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => FormularioProducto(
                  vendedorActual: vendedorActual,
                  onGuardar: onGuardarProducto,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// VISTA: EDITAR PERFIL DE TIENDA
// -------------------------------------------------------------

class VistaEditarPerfilTienda extends StatefulWidget {
  final Vendedor vendedor;
  final Function(Vendedor) onGuardarPerfil;

  const VistaEditarPerfilTienda({
    super.key,
    required this.vendedor,
    required this.onGuardarPerfil,
  });

  @override
  State<VistaEditarPerfilTienda> createState() =>
      _VistaEditarPerfilTiendaState();
}

class _VistaEditarPerfilTiendaState extends State<VistaEditarPerfilTienda> {
  late TextEditingController _ctrlNombre;
  late TextEditingController _ctrlDescripcion;
  String? _fotoPerfil;
  bool _subiendo = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _ctrlNombre = TextEditingController(text: widget.vendedor.nombreTienda);
    _ctrlDescripcion =
        TextEditingController(text: widget.vendedor.descripcionTienda);
    _fotoPerfil = widget.vendedor.fotoPerfil;
  }

  Future<void> _elegirFoto() async {
    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (img != null) {
      setState(() {
        _fotoPerfil = img.path;
      });
    }
  }

  Future<void> _guardar() async {
    final nom = _ctrlNombre.text.trim();
    if (nom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre de la tienda es obligatorio')),
      );
      return;
    }

    setState(() => _subiendo = true);

    String? fotoFinal = _fotoPerfil;
    if (_fotoPerfil != null && File(_fotoPerfil!).existsSync()) {
      final urlSubida =
          await subirImagenASupabase(_fotoPerfil!, 'perfiles');
      if (urlSubida != null) {
        fotoFinal = urlSubida;
      }
    }

    final actualizado = Vendedor(
      id: widget.vendedor.id,
      usuario: widget.vendedor.usuario,
      contrasena: widget.vendedor.contrasena,
      nombreTienda: nom,
      descripcionTienda: _ctrlDescripcion.text.trim(),
      fotoPerfil: fotoFinal,
    );

    await widget.onGuardarPerfil(actualizado);

    if (mounted) {
      setState(() => _subiendo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Perfil de la tienda actualizado con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: ClipOval(
                  child: widgetImagenCargada(
                    _fotoPerfil,
                    height: 108,
                    width: 108,
                    iconoVacio: Icons.storefront,
                  ),
                ),
              ),
              IconButton.filled(
                icon: const Icon(Icons.camera_alt, size: 20),
                onPressed: _subiendo ? null : _elegirFoto,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '@${widget.vendedor.usuario}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrlNombre,
            decoration: const InputDecoration(
              labelText: 'Nombre de la tienda / puesto *',
              prefixIcon: Icon(Icons.store),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrlDescripcion,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Descripción breve de tu tienda',
              hintText: 'Ej. Venta de accesorios, dulces y snacks en campus.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _subiendo
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_subiendo
                  ? 'Guardando imagen...'
                  : 'Guardar Perfil de Tienda'),
              onPressed: _subiendo ? null : _guardar,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// FORMULARIO CREAR/EDITAR PRODUCTO (CON SUBIDA A STORAGE)
// -------------------------------------------------------------

class FormularioProducto extends StatefulWidget {
  final Vendedor vendedorActual;
  final Producto? productoEditar;
  final Function(Producto) onGuardar;

  const FormularioProducto({
    super.key,
    required this.vendedorActual,
    this.productoEditar,
    required this.onGuardar,
  });

  @override
  State<FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<FormularioProducto> {
  final _ctrlNombre = TextEditingController();
  final _ctrlDescripcion = TextEditingController();
  final _ctrlPrecio = TextEditingController();
  final _ctrlStock = TextEditingController();
  final _ctrlUbicacion = TextEditingController();
  final _ctrlEntregaEstimada = TextEditingController();
  final _ctrlDatosTarjeta = TextEditingController();

  bool _disponibleInmediato = true;
  bool _activo = true;
  bool _subiendo = false;
  String _metodoPago = 'Ambas';
  String? _rutaFoto;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.productoEditar != null) {
      final p = widget.productoEditar!;
      _ctrlNombre.text = p.nombre;
      _ctrlDescripcion.text = p.descripcion;
      _ctrlPrecio.text = p.precio.toString();
      _ctrlStock.text = p.stock.toString();
      _ctrlUbicacion.text = p.ubicacion;
      _ctrlEntregaEstimada.text = p.entregaEstimada;
      _ctrlDatosTarjeta.text = p.datosTarjeta;
      _disponibleInmediato = p.disponibleInmediato;
      _activo = p.activo;
      _metodoPago = p.metodoPago;
      _rutaFoto = p.rutaFoto;
    } else {
      _ctrlEntregaEstimada.text = 'Inmediata (10-15 mins)';
    }
  }

  Future<void> _tomarOFoto(ImageSource fuente) async {
    final XFile? imagen = await _picker.pickImage(
      source: fuente,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (imagen != null) {
      setState(() {
        _rutaFoto = imagen.path;
      });
    }
  }

  Future<void> _guardar() async {
    final nombre = _ctrlNombre.text.trim();
    final descripcion = _ctrlDescripcion.text.trim();
    final precio = double.tryParse(_ctrlPrecio.text.trim()) ?? 0.0;
    final stock = int.tryParse(_ctrlStock.text.trim()) ?? 0;
    final ubicacion = _ctrlUbicacion.text.trim();
    final entrega = _ctrlEntregaEstimada.text.trim().isEmpty
        ? 'Inmediata'
        : _ctrlEntregaEstimada.text.trim();

    if (nombre.isEmpty || precio <= 0 || ubicacion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifica los campos obligatorios')),
      );
      return;
    }

    setState(() => _subiendo = true);

    String? fotoUrlFinal = _rutaFoto;
    if (_rutaFoto != null && File(_rutaFoto!).existsSync()) {
      final urlSubida =
          await subirImagenASupabase(_rutaFoto!, 'productos');
      if (urlSubida != null) {
        fotoUrlFinal = urlSubida;
      }
    }

    final p = Producto(
      id: widget.productoEditar?.id ??
          'prod_${DateTime.now().millisecondsSinceEpoch}',
      idVendedor: widget.vendedorActual.id,
      nombreTiendaVendedor: widget.vendedorActual.nombreTienda,
      usuarioVendedor: widget.vendedorActual.usuario,
      nombre: nombre,
      descripcion: descripcion,
      precio: precio,
      stock: stock,
      ubicacion: ubicacion,
      disponibleInmediato: _disponibleInmediato,
      entregaEstimada: entrega,
      metodoPago: _metodoPago,
      datosTarjeta: _ctrlDatosTarjeta.text.trim(),
      rutaFoto: fotoUrlFinal,
      activo: _activo,
    );

    await widget.onGuardar(p);

    if (mounted) {
      setState(() => _subiendo = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productoEditar != null
            ? 'Editar Producto'
            : 'Nuevo Producto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _subiendo ? null : () => _tomarOFoto(ImageSource.gallery),
              child: Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: _rutaFoto != null && _rutaFoto!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: widgetImagenCargada(
                          _rutaFoto,
                          height: 170,
                          width: double.infinity,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Toca para añadir foto del producto'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrlNombre,
              decoration: const InputDecoration(labelText: 'Nombre del producto *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrlDescripcion,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción del producto (Máx. 500 caracteres)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrlPrecio,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio (\$) *'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ctrlStock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock disponible *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('¿Disponibilidad inmediata para entrega?'),
              subtitle: Text(
                _disponibleInmediato
                    ? 'Listo para entregar en el momento'
                    : 'Bajo pedido o elaboración previa',
                style: const TextStyle(fontSize: 12),
              ),
              value: _disponibleInmediato,
              activeThumbColor: Colors.blueAccent,
              onChanged: (val) => setState(() => _disponibleInmediato = val),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visibilidad del producto'),
              subtitle: Text(
                _activo ? 'Visible en catálogo' : 'Pausado/oculto',
                style: const TextStyle(fontSize: 12),
              ),
              value: _activo,
              activeThumbColor: Colors.green,
              onChanged: (val) => setState(() => _activo = val),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrlEntregaEstimada,
              decoration: const InputDecoration(
                labelText: 'Tiempo de entrega estimado *',
                hintText: 'Ej. 10 a 15 min, Hoy mismo, 24 horas',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrlUbicacion,
              decoration: const InputDecoration(
                labelText: 'Punto o ubicación de entrega *',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _metodoPago,
              decoration: const InputDecoration(
                labelText: 'Forma de pago aceptada',
                prefixIcon: Icon(Icons.payment),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Efectivo',
                  child: Text('Solo Efectivo'),
                ),
                DropdownMenuItem(
                  value: 'Tarjeta',
                  child: Text('Solo Tarjeta / Transferencia'),
                ),
                DropdownMenuItem(
                  value: 'Ambas',
                  child: Text('Ambas formas (Efectivo y Tarjeta)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _metodoPago = val);
                }
              },
            ),
            const SizedBox(height: 12),
            if (_metodoPago != 'Efectivo')
              TextField(
                controller: _ctrlDatosTarjeta,
                decoration: const InputDecoration(
                  labelText: 'Datos para pago (CLABE o Banco)',
                  prefixIcon: Icon(Icons.credit_card),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _subiendo ? null : _guardar,
                child: Text(_subiendo ? 'Subiendo imagen y guardando...' : 'Guardar Producto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// ESCÁNER DE CÁMARA
// -------------------------------------------------------------

class PantallaEscaner extends StatefulWidget {
  final String idVendedor;
  final Function(String folio, String nom, double precio) onValidado;

  const PantallaEscaner({
    super.key,
    required this.idVendedor,
    required this.onValidado,
  });

  @override
  State<PantallaEscaner> createState() => _PantallaEscanerState();
}

class _PantallaEscanerState extends State<PantallaEscaner> {
  bool _procesado = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR Comprobante')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_procesado) return;
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            final raw = barcode.rawValue;
            if (raw != null) {
              try {
                final Map<String, dynamic> data = jsonDecode(raw);
                if (data['idVendedor'] != widget.idVendedor) {
                  _procesado = true;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Este código pertenece a otra tienda o vendedor.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                _procesado = true;
                Navigator.pop(context);
                widget.onValidado(
                  data['folio'] ?? 'SIN-FOLIO',
                  data['nombre'] ?? 'Producto',
                  (data['precio'] as num).toDouble(),
                );
                break;
              } catch (_) {}
            }
          }
        },
      ),
    );
  }
}