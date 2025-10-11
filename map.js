var map = null;
var minZoom = 9;
var iniZoom = 13;
var regiones = [];
var comunas = [];
var markers = [];
var miMarcador = null;
var locales = [];
var iconos = [];
var titulos = [];
var lat = '';
var lng = '';
var fecha = '';
var actualizar = true;
var filtro = '';
var filtroAnterior = '';
var desplazamiento = 0.00012;
var coordAct = { latMin:0, latMax:0, lngMin:0, lngMax:0}
var coordAnt = { latMin:0, latMax:0, lngMin:0, lngMax:0}
var limpiarComuna = 0; //limpiar comuna al desplazarse
var limpiarComunaPasos = 3; //numero de desplazamientos antes de limpiar
var tipoBusqueda = ''; //sector, region
var tipoFiltro = '';

var Mapa = {
    init: function() {
        $('[data-toggle="tooltip"]').tooltip();
        this.iniciarMapa('mapid', -39.83, -73.2);
        this.regiones();
        this.fechas();
        this.iconos();
        filtro = '';
    },
    iniciarMapa: function (divmapa, latitud, longitud) {
        let container = L.DomUtil.get(divmapa);
        if(container != null){
            container._leaflet_id = null;
        }
        map = L.map(divmapa).setView([parseFloat(latitud), parseFloat(longitud)], 4);
        
        L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>',
            maxZoom:18,
            minZoom:4
        }).addTo(map);

        map.on('moveend', function(e) { Mapa.actualizarMapa(); 
            // resetear comuna
            if(limpiarComuna == limpiarComunaPasos) { 
                let comuna = $('#comuna option:selected').val();
                if( comuna != 0) {
                    $("#comuna").val($('#comuna option:eq(0)').val()).change();
                }
                limpiarComuna = 0;
            } else if(limpiarComuna < limpiarComunaPasos) {
                limpiarComuna++;
            } 
        });

        map.on('zoomend', function(e) { Mapa.actualizarMapa(); });
        map.on('popupopen', function(e) { 
            let im = e.popup._source.markerid;
            if(im === undefined) return;
            Mapa.horario(im);
            actualizar = false;
        });
	},
    regiones: function () {
        tipoBusqueda = 'region';
        lat = '';
        lng = '';

        $.post('./mfarmacias/mapa.php', { func:'regiones' }, 
        function(datos) {
            if(datos.correcto) {
                let options = '<option value="0">Región</option>';
                $.each(datos.respuesta, function(id, reg) {
                    options += '<option data-lat="'+reg.lat+'" data-lng="'+reg.lng+'" value="'+reg.id+'">'+reg.nombre+'</option>';
                    regiones[reg.id] = reg.nombre;
                })
                $('#region').html(options);
            }
        }, 'json').
        fail(function(xhr) { });

        $.post('./mfarmacias/mapa.php', { func:'comunas' }, 
        function(datos) {
            if(datos.correcto) {
                $.each(datos.respuesta, function(id, com) { comunas[com.id] = com.nombre; });
            }
        }, 'json').
        fail(function(xhr) { });
    },
    comunas: function () {
        tipoBusqueda = 'region';
        lat = '';
        lng = '';

        let region = $('#region option:selected').val();
        let options = '<option value="0">Comuna</option>';
        $('#comuna').html(options);
   
        $.post('./mfarmacias/mapa.php', { func:'comunas', region:region }, 
        function(datos) {
            if(datos.correcto) {
                $.each(datos.respuesta, function(id, comuna) {
                    options += '<option data-lat="'+comuna.lat+'" data-lng="'+comuna.lng+'" value="'+comuna.id+'">'+comuna.nombre+'</option>';
                })
                $('#comuna').html(options);
            }
        }, 'json').
        fail(function(xhr) { });

        if( filtro != '') {
            Mapa.buscar(filtro);
        } else if(filtro == '') {    
            Mapa.buscar('turnos');
        } else {
            Mapa.foco();
        } 
    }, 
    locales: function() {
        let metro = this.metropolitana(true);
        if( metro == 0) {
            this.foco();
        } else if( metro == 1) {
            Mapa.buscar(( filtro != '')?filtro:'turnos');
        }
    },
    fechas: function () {
        $.post( 
            './mfarmacias/mapa.php', { func:'fechas' }, 
            function(datos) {
                if(datos.correcto) {
                    let options = ``;
                    let indice = 1;
                    options = `<option value="0" selected>Fecha de turno</option>`;
                    $.each(datos.respuesta, function(id, value) {
                        options += `<option value="`+id+`" >Turno `+value+`</option>`;
                        indice += 1;
                    })
                    $('#fecha').html(options);
                }
            }, 'json').
            fail(function(xhr) { });
    },
    iconos: function() {
        $.post('./mfarmacias/mapa.php', { func:'iconos' }, 
        function(datos) { 
            $.each(datos.titulos, function(id, titulo) { titulos[id] = titulo; });
            $.each(datos.iconos, function(id, icono) { iconos[id] = icono; });
        }, 'json');
    },
    actualizarMapa: function() {
        let ampliar = ( filtro != filtroAnterior)?0.025:0;
        let bounds = map.getBounds();
        let latMin = bounds.getSouthWest().lat;
        let latMax = bounds.getNorthEast().lat;
        let lngMin = bounds.getSouthWest().lng;
        let lngMax = bounds.getNorthEast().lng;
        let region = $('#region option:selected').val();

        if(latMin-latMax == 0 && lngMin-lngMax == 0) return;

        coordAct = {latMin:latMin-ampliar, latMax:latMax+ampliar, lngMin:lngMin-ampliar, lngMax:lngMax+ampliar}

        if( (filtro != filtroAnterior) || (coordAnt.latMin == 0 && coordAnt.latMax == 0 && coordAnt.lngMin == 0 && coordAnt.lngMax == 0) || 
        (coordAnt.latMin > coordAct.latMin || coordAnt.latMax < coordAct.latMax || coordAnt.lngMin > coordAct.lngMin || coordAnt.lngMax < coordAct.lngMax )) {
            if( filtro != '' && tipoBusqueda == 'sector' && actualizar ) {
                $('#loading').show();
                let hora = Mapa.hora();
                $.post('./mfarmacias/mapa.php', { func:'sector', filtro:filtro, fecha:fecha, region:region, lat:lat, lng:lng, latMin:coordAct.latMin, latMax:coordAct.latMax, lngMin:coordAct.lngMin, lngMax:coordAct.lngMax, hora:hora},
                function(datos) {
                    Mapa.mapaLocales(datos.respuesta.locales, datos.correcto);
                    $('#loading').hide();
                }, 'json').
                fail(function(xhr) { $('#loading').hide(); });
            } else {
                actualizar = true;
            }
            coordAnt = coordAct;
            filtroAnterior = filtro;
        }
    },
    horario: function (im) {
        let lc = locales.find(local => local.im === im);
        let tipo = iconos[lc.tp];
        let titulo = titulos[lc.tp];

        lc.func = 'local';
        lc.fecha = fecha;

        map.setView([parseFloat(lc.lt)+0.002, parseFloat(lc.lg)], 16); // centrar marcador

        $.post('./mfarmacias/mapa.php', lc,
        function(datos) {
            let local = datos.respuesta.local;
            let horario = datos.respuesta.horario;
            let turno = (horario.turno !== '' && horario.turno !== undefined);
            //<label class="mt-1"><b>`+((turno)?`Fecha Turno`:`Horario`)+`</b></label><br>`+((turno)?horario.turno:horario.dia)+`
            let marcas = ``;
            
            marcas = 
            `<div class="col-6 p-0 m-0"></div>
            <div class="col-2 p-0 m-0 flogo"></div>
             <div class="col-4 p-0 m-0">
                <div class="row tag-`+tipo+` text-dark text-left m-0" style="width:90px;padding: 5px 2px 0px 8px;">
                    <div class="col-2 p-0 m-0"><img src="./mfarmacias/img/i`+tipo+`b.png" width="15"></div>
                    <div class="col-10 p-0 m-0">
                        <label class="w-100 text-center tag-titulo" >`+titulo+`</label> <!-- si este valor se presenta en  -->
                    </div>
                </div>
            </div>`;

            let etiqueta = `
            <div class="pl-2">
                <div class="row">
                    <div class="col-xl-9 col-lg-9 col-md-9 col-sm-12 p-0 m-0">
                        <label><b>`+local.nm+`</b></label><br>
                        `+((turno)?`<hr><label class="pt-0 mb-0"><b>Fecha Turno</b></label><br>`+horario.turno+`<hr>`:``)
                         +((turno)?``:`<label class="pt-2 mb-0"><b>Horario Semanal</label></b><br>`+horario.semana+``)+`
                    </div>
                    <div class="col-xl-3 col-lg-3 col-md-3 col-sm-0 p-0 m-0 text-center flogo"><img src="`+(( local.img !== '' && local.img !== undefined)?`./mfarmacias/mapa.php?imagen=`+local.img:`./mfarmacias/img/logo.svg`)+`" class="rounded img-fluid p-0" width=50></div>
                </div>
                <div class="row">
                    <div class="col-12 p-0 m-0">
                        `+((turno)?`<label class="pt-2 mb-0"><b>Horario Semanal</b></label><br>`+horario.semana+``:``)+`
                        <label class="pt-2 mb-0"><b>Dirección</b></label><br>
                        `+ucwords(local.dr)+`,<br>`+comunas[local.cm]+`, `+regiones[local.rg]+`.<br><img src="./mfarmacias/img/map.svg" width="15">&nbsp;<a href="https://www.google.com/maps/search/?api=1&query=`+ucwords(local.dr)+`, `+comunas[local.cm]+`, `+regiones[local.rg]+`" target='_blank' >¿Cómo llegar?</a><br>`
                        +((local.tl !== '')?`<label class="pt-2 mb-0"><b>Teléfono</b></label><br><a href='tel:`+local.tl+`'>`+local.tl+`</a>`:``)+`
                    </div>
                </div>
                <div class="row pt-0 pr-1">`+marcas+`</div>
            </div>`;
            $('#h'+im).html(etiqueta);
        }, 'json').
        fail(function(xhr, textStatus, errorThrown) { });
    },
    mapaMarcador: function(local) {
        let tipo = iconos[local.tp];
        let	icono = L.icon({ iconUrl: './mfarmacias/img/mapa/'+tipo+'.png',  iconSize: [25, 35], iconAnchor: [10, 10]});
        let etiqueta = `<div id="h`+local.im+`"></div>`;
        markers[local.im] = L.marker([parseFloat(local.lt), parseFloat(local.lg)],{icon: icono}).addTo(map).bindPopup(etiqueta);
        markers[local.im].markerid = local.im;
    },
    mapaResetear: function() {
        $.each(markers, function(i) { if ( markers[i] != undefined && map.hasLayer(markers[i]) ) map.removeLayer(markers[i]); });
        markers = [];
        locales = [];
        coordAct = { latMin:0, latMax:0, lngMin:0, lngMax:0}
        coordAnt = { latMin:0, latMax:0, lngMin:0, lngMax:0}

        let region = $('#region option:selected').val();
        let comuna = $('#comuna option:selected').val();
        if( miMarcador !== null && (region != 0 || comuna != 0)) {
            map.removeLayer(miMarcador);
            miMarcador = null;
        }
        $('#locales').html('');
    }, 
    mapaLocales: function(rLocales, correcto) {
        let existe = false;
        if(correcto) {
            $.each(rLocales, function(id, local){
                if( !isNaN(parseFloat(local.lt)) && !isNaN(parseFloat(local.lg)) && parseFloat(local.lt) != 0 && parseFloat(local.lg) != 0 ) {
                    existe = locales.some(l => l.im === local.im);
                    if (!existe) {
                        Mapa.mapaMarcador(local);
                        locales.push(local);
                    }
                }
            });
        }
    },
    metropolitana: function (msj) {
        let region = $('#region option:selected').val();
        if( tipoBusqueda == 'region' && region == 13 && ( filtro == 'todos' || filtro == 'privado')) { 
            let comuna = $('#comuna option:selected').val();
            if( comuna > 0) {
                return 1;
            } else {
                if(msj && limpiarComuna != limpiarComunaPasos) {
                    _Alerta.info("Por favor, seleccione una comuna");
                }
                return 2;
            }
        }
        return 0;
    },
    buscarFecha: function() {
        fecha = $('#fecha option:selected').val();
        if(fecha != '0' || filtro == 'turnos') {
            Mapa.buscar('turnos');
        }
    },
    buscar: function(tipo) { 
        limpiarComuna = 0;
        filtro = tipo;

        $('.text-turnos').parent().removeClass('btn-seleccionado');
        $('.text-movil').parent().removeClass('btn-seleccionado');
        $('.text-popular').parent().removeClass('btn-seleccionado');
        $('.text-privado').parent().removeClass('btn-seleccionado');
        $('.text-almacen').parent().removeClass('btn-seleccionado');
        $('.text-todos').parent().removeClass('btn-seleccionado');
        
        $('.text-'+tipo).parent().addClass('btn-seleccionado');
        if(tipo == 'turnos') {
            $('#fecha').show();
            fecha = $('#fecha option:selected').val();
            if(fecha == '0') {
                fecha = $('#fecha option:eq(1)').val();
                $("#fecha").val(fecha).change();
            }
        } else {
            $('#fecha').hide();
            fecha = '';
            $("#fecha").val(0).change();
        } 

        if(this.metropolitana(true) == 2) {
            return;
        }

        Mapa.mapaResetear();

        if( tipoBusqueda == 'sector') {
            Mapa.ubicacion();
        } else if( tipoBusqueda == 'region') {
            let comuna = $('#comuna option:selected').val();
            let region = $('#region option:selected').val();

            if( comuna > 0 || region > 0 ) {
                $('#loading').show();
                let hora = Mapa.hora();

                $.post('./mfarmacias/mapa.php', { func:'region', filtro:filtro, fecha:fecha, region:region, hora:hora},
                function(datos) {
                    Mapa.mapaLocales(datos.respuesta.locales, datos.correcto);
                    $('#loading').hide();
                }, 'json').
                fail(function(xhr) { $('#loading').hide(); });
            }
            Mapa.foco();
        }
        $('.btn').tooltip('hide');
    },
    foco: function() {
        let comuna = $('#comuna option:selected').val();
        let region = $('#region option:selected').val();

        if(limpiarComuna == limpiarComunaPasos) { return; }
        limpiarComuna = 0;

        if( comuna > 0 || region > 0 ) {
            let coordenadas = (comuna > 0 )?$('#comuna').children(':selected'):$('#region').children(':selected');
            let mzoom = (this.metropolitana(false) == 1)?14:iniZoom;
            map.setView([parseFloat(coordenadas.attr('data-lat')), parseFloat(coordenadas.attr('data-lng'))], mzoom);
            map.setMinZoom((this.metropolitana(false) == 1)?12:minZoom);
        }
    },
    ubicacion: function() {
        if(navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(function(position) {
                tipoBusqueda = 'sector';
                
                Mapa.mapaResetear();

                $('#region option:eq(0)').prop('selected', true);
                $('#comuna').html('<option value="0">Comuna</option>');

                let	icono = L.icon({ iconUrl: './mfarmacias/img/mapa/ubicacion.png',  iconSize: [25, 35], iconAnchor: [10, 10]});
                lat = position.coords.latitude;
                lng = position.coords.longitude;

                //lat = -33.448576066646716;
                //lng = -70.65256048735613;
                map.setView([lat, lng], 14);
                map.setMinZoom(minZoom);

                if(filtro == '') {
                    Mapa.buscar('turnos');
                }
                miMarcador = L.marker([lat, lng],{icon: icono}).addTo(map).bindPopup('<div class="ubicacion w-100 text-center"><b>Esta es mi ubicación</b></div>').openPopup();
                
            }, function() {
                alert('Debe aceptar el permiso localización o seleccionar una región');
            });   
        }
    },
    hora: function() {
        tiempo = new Date()
        h = tiempo.getHours()
        m = tiempo.getMinutes()
        s = tiempo.getSeconds()
        horaActual = ((h < 10)?('0'.concat(h)):h)+':'+((m < 10)?('0'.concat(m)):m)+':'+((s < 10)?('0'.concat(s)):s);
        return horaActual;
    }
}
Mapa.init();

function ucwords(str) {
    return (str+'').replace(/^([a-z])|\s+([a-z])/g, function ($1) { return $1.toUpperCase(); });
}

function reloj() {
    tiempo = new Date()
    h = tiempo.getHours()
    m = tiempo.getMinutes()
    s = tiempo.getSeconds()
    horaActual =  ((h < 10)?('0'.concat(h)):h)+":"+((m < 10)?('0'.concat(m)):m)+":"+((s < 10)?('0'.concat(s)):s) 

    $('#reloj').html(horaActual);
    setTimeout("reloj()",1000)
}