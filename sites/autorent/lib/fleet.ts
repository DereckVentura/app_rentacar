export const locations = [
 {id:1,nombre:'La Unión',direccion:'La Unión, El Salvador · confirma el punto de entrega',latitud:'13.3369',longitud:'-87.8439',tipo:'sucursal',activo:true},
 {id:2,nombre:'San Miguel',direccion:'San Miguel, El Salvador · confirma el punto de entrega',latitud:'13.4833',longitud:'-88.1833',tipo:'sucursal',activo:true},
];
export const fleet = ['outlander-gris','outlander-roja','rogue-gris'].map((slug,i)=>({
 id:i+1, marca:{id:i===2?2:1,nombre:i===2?'Nissan':'Mitsubishi'},modelo:{id:i===2?2:1,nombre:i===2?'Rogue':'Outlander'},categoria:{id:1,nombre:'SUV'},
 anio:i===2?2016:2017,precio_dia:i===2?'35.00':'40.00',placa:['P 43 9C5','P 37 DE9','P 15 F44'][i],kilometraje:null,
 reservable:true,disponible:true,publicado:true,activo:true,estado_operativo:'disponible',ubicacion:locations[0],ubicacion_actual_id:1,
 imagen_url:`/vehicles/${slug}-1.jpeg`,descripcion:'Vehículo de Rent a Car Molina. Consulta las fotografías y los detalles de la unidad.',
 ficha:{color:i===1?'Rojo':'Gris',traccion:i===2?null:'FWD',anio_verificado:false,version:null,plazas:null,motor_litros:null,potencia_hp:null,transmision:null,combustible:null,observaciones:'Año indicado por el propietario. Verificación documental pendiente.',
 fotos:[{url:`/vehicles/${slug}-1.jpeg`,alt:`${i===2?'Nissan Rogue':'Mitsubishi Outlander'} ${i===1?'roja':'gris'} · fotografía 1`},{url:`/vehicles/${slug}-2.${i===1?'jpg':'jpeg'}`,alt:'Fotografía adicional de la unidad'}],referencias:[]},
}));
export const documents = [
 {id:'privacidad',titulo:'Aviso de privacidad',texto:'AutoRent utiliza los datos de tu cuenta para gestionar reservas. La licencia de conducir se solicita para verificar al conductor y se guarda con acceso restringido al titular y la administración. Las contraseñas se guardan mediante hash. Puedes gestionar solicitudes sobre tus datos desde tu cuenta o contactar a Rent a Car Molina.'},
 {id:'terminos',titulo:'Condiciones de uso',texto:'Antes de confirmar, revisa el vehículo, los puntos de entrega, las fechas y el total. Cada bloque de 24 horas iniciado cuenta como un día de alquiler. Es obligatorio adjuntar ambas caras de una licencia vigente durante toda la reserva. La administración verificará la licencia antes de entregar el vehículo. Las solicitudes requieren validación del administrador en un plazo de 3 horas. Si no se validan, vencen y liberan las fechas. Puedes cancelar desde Mis reservas antes del inicio. Coordina las condiciones de entrega y pago con Rent a Car Molina.'},
];
export const business = {nombre:'Rent a Car Molina',direccion:'Mercado Municipal de La Unión',municipio:'La Unión',telefono:'+503 7149 2867',correo:null,faq:[
 {pregunta:'¿Cuáles son las tarifas?',respuesta:'Ambas Mitsubishi Outlander: $40 por día. Nissan Rogue: $35 por día.'},
 {pregunta:'¿Qué documento necesito?',respuesta:'Adjunta ambas caras de una licencia de conducir vigente durante todo el alquiler.'},
 {pregunta:'¿Cómo elijo las fechas?',respuesta:'Los días reservados aparecen en gris y no se pueden seleccionar. El total se muestra antes de confirmar.'},
]};
