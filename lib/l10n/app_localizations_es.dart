// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Hestia';

  @override
  String get splashTagline => 'Un espacio privado para tu gente';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get language => 'Idioma';

  @override
  String get settings => 'Ajustes';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get appearance => 'Apariencia';

  @override
  String get background => 'Fondo';

  @override
  String get backgroundDefault => 'Predeterminado';

  @override
  String get backgroundChooseColor => 'Elegir color';

  @override
  String get backgroundChooseImage => 'Elegir imagen';

  @override
  String get reset => 'Restablecer';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get close => 'Cerrar';

  @override
  String get continueAction => 'Continuar';

  @override
  String get search => 'Buscar';

  @override
  String get refresh => 'Actualizar';

  @override
  String get accept => 'Aceptar';

  @override
  String get decline => 'Rechazar';

  @override
  String get request => 'Solicitud';

  @override
  String get error => 'Error';

  @override
  String get server => 'Servidor';

  @override
  String get serverUrl => 'URL del servidor';

  @override
  String serverConnected(String host) {
    return 'Conectado a $host';
  }

  @override
  String get serverDisconnected => 'Desconectado';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get registration => 'Registro';

  @override
  String get register => 'Registrarse';

  @override
  String get nicknameRequired => 'El nombre de usuario es obligatorio';

  @override
  String get passwordRequired => 'La contraseña es obligatoria';

  @override
  String get nicknameTooShort =>
      'El nombre de usuario debe tener al menos 2 caracteres';

  @override
  String get passwordTooShort =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get chooseNickname => 'Elige un nuevo nombre de usuario';

  @override
  String get yourNickname => 'Tu nombre de usuario';

  @override
  String get choosePassword => 'Elige una contraseña';

  @override
  String get password => 'Contraseña';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get chats => 'Chats';

  @override
  String get contacts => 'Contactos';

  @override
  String get requests => 'Solicitudes';

  @override
  String get addContact => 'Añadir contacto';

  @override
  String get privacy => 'Privacidad';

  @override
  String get backup => 'Copia de seguridad';

  @override
  String get devices => 'Dispositivos';

  @override
  String get allowUsernameSearch => 'Permitir búsqueda por nombre de usuario';

  @override
  String get messagesFrom => 'Mensajes de';

  @override
  String get callsFrom => 'Llamadas de';

  @override
  String get everyone => 'Todos';

  @override
  String get noChatsYet => 'Aún no hay chats.';

  @override
  String get noContactsYet => 'Añade un contacto para empezar a hablar';

  @override
  String get firstRunNoContactsTitle =>
      'Añade un contacto para empezar a hablar';

  @override
  String get firstRunNoContactsBody =>
      'Busca a alguien por nombre de usuario y envía una solicitud.';

  @override
  String get hintAddContact => 'Busca a alguien por nombre de usuario';

  @override
  String get hintRequests => 'Aquí aparecen las solicitudes de contacto';

  @override
  String get hintMessageInput => 'Escribe un mensaje';

  @override
  String get noPendingRequests => 'No hay solicitudes pendientes.';

  @override
  String get findUsername => 'Buscar nombre de usuario';

  @override
  String get username => 'Nombre de usuario';

  @override
  String get enterUsername => 'Introduce un nombre de usuario';

  @override
  String get userFound => 'Usuario encontrado';

  @override
  String get userNotFound =>
      'Usuario no encontrado o la búsqueda está desactivada.';

  @override
  String get sendContactRequest => 'Enviar solicitud de contacto';

  @override
  String requestSentTo(String name) {
    return 'Solicitud enviada a $name';
  }

  @override
  String get retentionContactAdded =>
      'Contacto añadido. Puedes iniciar un chat.';

  @override
  String get retentionFirstMessageSent =>
      'Mensaje enviado. Hestia mantiene la conversación tranquila y privada.';

  @override
  String get retentionStartChatHint =>
      'Abre un chat y envía tu primer mensaje cuando estés listo.';

  @override
  String get retentionDayReminder =>
      'Hace tiempo que no habláis. Tus chats privados están aquí cuando quieras responder con calma.';

  @override
  String get retentionThreeDayReminder =>
      'Un recordatorio suave: tus conversaciones de confianza esperan aquí.';

  @override
  String get retentionNewMessages => 'Tienes mensajes nuevos.';

  @override
  String get contact => 'Contacto';

  @override
  String get contactOnline => 'En línea ahora';

  @override
  String get block => 'Bloquear';

  @override
  String get unblockUser => 'Desbloquear usuario';

  @override
  String get blockUser => 'Bloquear usuario';

  @override
  String get wantsToAddYou => 'Quiere añadirte como contacto';

  @override
  String get attachment => 'Adjunto';

  @override
  String attachmentNamed(String name) {
    return 'Adjunto: $name';
  }

  @override
  String get mute => 'Silenciar';

  @override
  String get unmute => 'Quitar silencio';

  @override
  String get pin => 'Fijar';

  @override
  String get unpin => 'Desfijar';

  @override
  String get archive => 'Archivar';

  @override
  String get deleteForMe => 'Eliminar para mí';

  @override
  String get backupWarning =>
      'Las copias de seguridad se cifran localmente. Guarda bien la contraseña: sin ella no se puede restaurar la copia.';

  @override
  String get backupPassword => 'Contraseña de la copia';

  @override
  String get confirmBackupPassword => 'Confirma la contraseña de exportación';

  @override
  String get backupPasswordsDoNotMatch =>
      'Las contraseñas de la copia no coinciden.';

  @override
  String get backupExportCancelled => 'Exportación de copia cancelada.';

  @override
  String get backupSaved => 'Copia de seguridad guardada.';

  @override
  String get backupImported =>
      'Copia importada. Los datos locales se han restaurado.';

  @override
  String get import => 'Importar';

  @override
  String get export => 'Exportar';

  @override
  String get noSessionData => 'Aún no hay datos de sesión.';

  @override
  String get unknownActivity => 'Actividad desconocida';

  @override
  String lastActive(String time) {
    return 'Última actividad $time';
  }

  @override
  String currentDevice(String name) {
    return '$name (actual)';
  }

  @override
  String get revoke => 'Revocar';

  @override
  String get logoutCurrent => 'Cerrar sesión actual';

  @override
  String get message => 'Mensaje';

  @override
  String get send => 'Enviar';

  @override
  String get sendFile => 'Enviar archivo';

  @override
  String messageSendFailed(String error) {
    return 'No se pudo enviar el mensaje: $error';
  }

  @override
  String fileSendFailed(String error) {
    return 'No se pudo enviar el archivo: $error';
  }

  @override
  String get noMessagesYet => 'Escribe el primer mensaje';

  @override
  String get reply => 'Responder';

  @override
  String get forward => 'Reenviar';

  @override
  String get forwardTo => 'Reenviar a';

  @override
  String get forwarded => 'Reenviado';

  @override
  String forwardedFrom(String name) {
    return 'Reenviado de $name';
  }

  @override
  String forwardedTo(String name) {
    return 'Reenviado a $name';
  }

  @override
  String forwardFailed(String error) {
    return 'No se pudo reenviar: $error';
  }

  @override
  String get noForwardTargets => 'No hay contactos disponibles para reenviar';

  @override
  String get cancelReply => 'Cancelar respuesta';

  @override
  String get originalMessage => 'Mensaje original';

  @override
  String get originalMessageUnavailable => 'Mensaje original no disponible';

  @override
  String savedTo(String path) {
    return 'Guardado en $path';
  }

  @override
  String saveFailed(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get open => 'Abrir';

  @override
  String get userUnavailable => 'El usuario no está disponible.';

  @override
  String get callRejected => 'La llamada fue rechazada.';

  @override
  String get sessionRevoked => 'Esta sesión fue revocada.';

  @override
  String couldNotConnectTo(String host) {
    return 'No se pudo conectar con $host';
  }

  @override
  String get unknownServerError => 'Error desconocido del servidor';

  @override
  String get authenticationRequired => 'Se requiere autenticación.';

  @override
  String get localFileNotFound => 'No se encontró el archivo local.';

  @override
  String get webAttachmentAvailable =>
      'El archivo está disponible en esta sesión del navegador.';

  @override
  String get webAttachmentUnavailable =>
      'El archivo no está disponible después de reiniciar el navegador.';

  @override
  String get attachmentTypeNotAllowed =>
      'Este tipo de adjunto no está permitido.';

  @override
  String get attachmentValidationFailed => 'No se pudo validar el adjunto.';

  @override
  String get attachmentTooLarge => 'El adjunto es demasiado grande.';

  @override
  String get attachmentLimits =>
      'Archivos permitidos: documentos, imágenes, audio y vídeo. Límites: imágenes 25 MB, audio/documentos 50 MB, vídeo 200 MB.';

  @override
  String get selectedFileReadFailed =>
      'No se pudo leer el archivo seleccionado.';

  @override
  String get forwardLocalFileUnavailable =>
      'No se pudo reenviar: el archivo local no está disponible.';

  @override
  String get attachmentUploadFailed => 'No se pudo subir el adjunto.';

  @override
  String peerKeyChangedCall(String name) {
    return 'La clave de cifrado de $name cambió. Verifica la huella antes de llamar.';
  }

  @override
  String peerNoEncryptionKey(String name) {
    return '$name aún no tiene clave de cifrado.';
  }

  @override
  String get encryptionKey => 'Clave de cifrado';

  @override
  String get verify => 'Verificar';

  @override
  String get trustKey => 'Confiar en la clave';

  @override
  String get trustNewKey => 'Confiar en la nueva clave';

  @override
  String get removeTrust => 'Quitar confianza';

  @override
  String get verifiedEncryptionKey => 'Clave de cifrado verificada';

  @override
  String get encryptionKeyChanged => 'La clave de cifrado cambió';

  @override
  String get noEncryptionKey => 'Sin clave de cifrado';

  @override
  String get verifyEncryptionKey => 'Verificar clave de cifrado';

  @override
  String get sendingBlockedKeyChanged =>
      'El envío está bloqueado hasta que vuelvas a verificar este contacto.';

  @override
  String get keyTrusted => 'Esta clave es de confianza en este dispositivo.';

  @override
  String get keyChangedWarning =>
      'Atención: esta clave cambió. Compara la huella antes de volver a confiar.';

  @override
  String get keyMissing =>
      'Este usuario aún no ha publicado una clave de cifrado.';

  @override
  String get keyUntrusted =>
      'Compara esta huella con la otra persona y luego confía en la clave.';

  @override
  String get noFingerprint => 'No hay huella disponible';

  @override
  String get audioCall => 'Llamada de audio';

  @override
  String get videoCall => 'Videollamada';

  @override
  String callFailed(String error) {
    return 'La llamada falló: $error';
  }

  @override
  String get anotherCallActive => 'Ya hay otra llamada activa';

  @override
  String get calling => 'Llamando...';

  @override
  String get connected => 'Conectado';

  @override
  String get muteCall => 'Silenciar';

  @override
  String get unmuteCall => 'Quitar silencio';

  @override
  String get endCall => 'Finalizar';

  @override
  String get incomingCall => 'Llamada entrante';

  @override
  String get voiceCall => 'Llamada de voz';

  @override
  String get pushSyncChannelDescription =>
      'Notificaciones de sincronización de mensajes y solicitudes de Hestia.';

  @override
  String get pushCallChannelDescription =>
      'Alertas de llamadas entrantes de Hestia.';

  @override
  String get newContactRequestNotification => 'Nueva solicitud de contacto';

  @override
  String get newMessageNotification => 'Nuevo mensaje';

  @override
  String get incomingVideoCallNotification => 'Videollamada entrante';

  @override
  String get incomingVoiceCallNotification => 'Llamada de voz entrante';

  @override
  String get unknownCaller => 'Desconocido';

  @override
  String get rejectCall => 'Rechazar';

  @override
  String get updateAvailable => 'Actualización disponible';

  @override
  String versionAvailable(String version) {
    return 'La versión $version está disponible.';
  }

  @override
  String get startingDownload => 'Iniciando descarga...';

  @override
  String downloadingProgress(String percent) {
    return 'Descargando... $percent%';
  }

  @override
  String get downloadFailedRetry => 'La descarga falló. Inténtalo de nuevo.';

  @override
  String get later => 'Más tarde';

  @override
  String get downloading => 'Descargando...';

  @override
  String get updateViaAppStore => 'Actualizar mediante App Store';

  @override
  String get downloadAndInstall => 'Descargar e instalar';

  @override
  String get openDownloadPage => 'Abrir página de descarga';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languagePolish => 'Polski';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageCzech => 'Čeština';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingGetStarted => 'Empezar';

  @override
  String get onboardingWelcomeTitle => 'Bienvenido a Hestia';

  @override
  String get onboardingWelcomeBody =>
      'Un mensajero tranquilo para chats, llamadas y archivos privados.';

  @override
  String get onboardingPrivacyTitle => 'Privacidad desde el diseño';

  @override
  String get onboardingPrivacyBody =>
      'Los mensajes usan claves de cifrado. Tus chats y archivos se guardan localmente.';

  @override
  String get onboardingHowItWorksTitle => 'Flujo simple';

  @override
  String get onboardingHowItWorksBody =>
      'Elige un servidor, añade contactos y aprueba solicitudes antes de chatear.';

  @override
  String get onboardingCallsFilesTitle => 'Llamadas y archivos';

  @override
  String get onboardingCallsFilesBody =>
      'Inicia llamadas de voz y comparte archivos en el mismo espacio protegido.';

  @override
  String get onboardingServerTitle => 'Elige tu servidor';

  @override
  String get onboardingServerBody =>
      'Usa el servidor predeterminado o conecta Hestia a tu propio servidor.';

  @override
  String get onboardingDefaultServer => 'Servidor predeterminado';

  @override
  String get onboardingCustomServer => 'Servidor personalizado';

  @override
  String get onboardingCustomServerBody =>
      'Para instalaciones self-hosted o privadas.';

  @override
  String get onboardingGetStartedTitle => 'Todo listo';

  @override
  String get onboardingGetStartedBody =>
      'Crea una cuenta nueva o inicia sesión con una existente.';
}
