import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:location/location.dart' as loc;
import 'package:http/http.dart' as http;
import 'package:weathergo/components/dicts.dart';

class TempPage extends StatefulWidget {
  const TempPage({Key? key}) : super(key: key);

  @override
  State<TempPage> createState() => _TempPageState();
}

class _TempPageState extends State<TempPage> {
  late double latitude;
  late double longitude;
  late Map addressData;
  late Map weatherData;
  bool isLoading = true;
  bool erroLocation = false;

  Future getWeatherData(latitude, longitude) async {
    var responseCurrent = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=b4eeb6ca3fc21a1d737a618e0a1c2d26&units=metric&lang=pt_br'));

    var dataCurrent = jsonDecode(utf8.decode(responseCurrent.bodyBytes));

    //var responseDaily = await http.get(Uri.parse(
    //    'https://api.openweathermap.org/data/2.5/forecast/daily?lat=$latitude&lon=$longitude&cnt=7&appid=b4eeb6ca3fc21a1d737a618e0a1c2d26&units=metric&lang=pt_br'));
//
    //var dataDaily = jsonDecode(utf8.decode(responseDaily.bodyBytes));
    //var data = {
    //  'current': dataCurrent,
    //  'daily': dataDaily,
    //};
    return dataCurrent;
  }

  Future getLoc() async {
    var location = loc.Location();
    late loc.PermissionStatus permissionGranted;
    late bool serviceEnabled;
    late loc.LocationData locationData;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return null;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        return null;
      }
    }
    location.changeSettings(accuracy: loc.LocationAccuracy.high);
    locationData = await location.getLocation();

    return locationData;
  }

  Future getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          latitude, longitude,
          localeIdentifier: 'pt_BR');

      return placemarks[1].toJson();
    } catch (e) {
      return null;
    }
  }

  Future loadLocation() async {
    if (erroLocation == true) {
      setState(() {
        isLoading = true;
      });
    }
    setState(() {
      erroLocation = false;
    });
    await getLoc().then((value) async {
      if (value == null) {
        setState(() {
          erroLocation = true;
          isLoading = false;
        });
        return;
      }
      setState(() {
        latitude = value.latitude!;
        longitude = value.longitude!;
      });
    });
    await getAddressFromLatLng(latitude, longitude).then((value) {
      setState(() {
        addressData = value;
      });
    });

    await getWeatherData(latitude, longitude).then((value) {
      setState(() {
        weatherData = value;
      });
    }).then((value) => {
          setState(() {
            isLoading = false;
          }),
        });
  }

  @override
  void initState() {
    super.initState();
    loadLocation();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    int tempCelsius = 0;
    int windSpeed = 0;
    String timeSunrise = '';
    String timeSunset = '';
    if (isLoading == false && erroLocation == false) {
      double temp = weatherData['main']['temp'];
      tempCelsius = temp.toInt();
      double wind = weatherData['wind']['speed'];
      //converter de m/s para km/h
      wind = wind * 3.6;
      windSpeed = wind.toInt();

      int sunrise = weatherData['sys']['sunrise'];
      int sunset = weatherData['sys']['sunset'];
      var dateSunrise = DateTime.fromMillisecondsSinceEpoch(sunrise * 1000);
      var dateSunset = DateTime.fromMillisecondsSinceEpoch(sunset * 1000);
      var formatter = DateFormat('HH:mm', 'pt_BR');
      timeSunrise = formatter.format(dateSunrise);
      timeSunset = formatter.format(dateSunset);
    }
    //pegar hora e data atual
    var now = DateTime.now();
    //converter para {diaDaSemana}, {dia} de {mes} de {ano}
    var formatter = DateFormat('EEE, d \'de\' MMMM \'de\' yyyy', 'pt_BR');
    String formatted = formatter.format(now);

    //formatar para: atualizado em {hora}:{minuto} de {dia}/{mes}/{ano}
    var formatterUpdate =
        DateFormat('\'atualizado em\' HH:mm \'de\' dd/MM/yyyy', 'pt_BR');
    String formattedUpdate = formatterUpdate.format(now);

    Map dadosTeste = {
      'cidade': 'Nova York',
      'temperatura': -3,
      'icone': '13n',
      'descricao': 'neve',
      'humidade': 90,
      'vento': 12,
      'nascerDoSol': '06:00',
      'porDoSol': '18:00',
    };

    return Scaffold(
      body: RefreshIndicator(
        backgroundColor: Colors.black,
        color: Colors.white,
        onRefresh: loadLocation,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                      (isLoading == false && erroLocation == false)
                          ? imagesBackground[dadosTeste['icone']]['local']
                          : imagesBackground['50d']['local']),
                  fit: BoxFit.cover,
                  colorFilter:
                      const ColorFilter.mode(Colors.black45, BlendMode.darken),
                  alignment: Alignment.bottomCenter.add((isLoading == false)
                      ? Alignment(
                          imagesBackground[dadosTeste['icone']]
                              ['alignmentHorizontal'],
                          imagesBackground[dadosTeste['icone']]
                              ['alignmentVertical'],
                        )
                      : const Alignment(0, 0)),
                ),
              ),
              child: (isLoading == true)
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : (erroLocation == true)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Não foi possível obter sua localização',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                              Padding(
                                padding:
                                    EdgeInsets.only(top: size.height * 0.05),
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      isLoading = true;
                                    });
                                    loadLocation();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    primary: Colors.white,
                                    onPrimary: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32.0),
                                    ),
                                  ),
                                  child: const Text(
                                    'Tentar novamente',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: size.height * 0.18),
                              child: Text(dadosTeste['cidade'],
                                  style: const TextStyle(
                                      fontSize: 35,
                                      fontFamily: 'Montserrat',
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                            Text(
                              formatted,
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'Montserrat',
                                color: Colors.white,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: size.height * 0.05),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    color: Colors.white,
                                  ),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text: '${dadosTeste['temperatura']}º',
                                      style: const TextStyle(
                                        fontSize: 90,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: 'C',
                                      style: TextStyle(
                                        fontSize: 50,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: size.width * 0.9,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  //Row(
                                  //  children: const [
                                  //    Icon(
                                  //      Icons.arrow_drop_down,
                                  //      color: Colors.white,
                                  //    ),
                                  //    Text(
                                  //      '12º',
                                  //      style: TextStyle(
                                  //        fontSize: 20,
                                  //        fontFamily: 'Montserrat',
                                  //        color: Colors.white,
                                  //      ),
                                  //    ),
                                  //  ],
                                  //),
                                  Row(
                                    children: [
                                      Image(
                                          image: NetworkImage(
                                              'https://openweathermap.org/img/w/${dadosTeste['icone']}.png')),
                                      Padding(
                                        padding: EdgeInsets.only(
                                            left: size.width * 0.02),
                                        child: Text(
                                          '${dadosTeste['descricao']}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontFamily: 'Montserrat',
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  //Row(
                                  //  children: const [
                                  //    Icon(
                                  //      Icons.arrow_drop_up,
                                  //      color: Colors.white,
                                  //    ),
                                  //    Text(
                                  //      '30º',
                                  //      style: TextStyle(
                                  //        fontSize: 20,
                                  //        fontFamily: 'Montserrat',
                                  //        color: Colors.white,
                                  //      ),
                                  //    ),
                                  //  ],
                                  //),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding:
                                    EdgeInsets.only(top: size.height * 0.08),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xff040B1B)
                                        .withOpacity(0.7),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(40),
                                      topRight: Radius.circular(40),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.water_drop,
                                                      color: Colors.white,
                                                    ),
                                                    Text(
                                                      '${dadosTeste['humidade']}%',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontFamily:
                                                            'Montserrat',
                                                        fontSize: 20,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    const BoxedIcon(
                                                      WeatherIcons.sunset,
                                                      color: Colors.white,
                                                    ),
                                                    Text(
                                                      dadosTeste['nascerDoSol'],
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontFamily:
                                                            'Montserrat',
                                                        fontSize: 20,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.air,
                                                      color: Colors.white,
                                                    ),
                                                    Text(
                                                      '${dadosTeste['vento']} km/h',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontFamily:
                                                            'Montserrat',
                                                        fontSize: 20,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    const BoxedIcon(
                                                      WeatherIcons.sunrise,
                                                      color: Colors.white,
                                                    ),
                                                    Text(
                                                      dadosTeste['porDoSol'],
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontFamily:
                                                            'Montserrat',
                                                        fontSize: 20,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                      //Padding(
                                      //  padding: EdgeInsets.only(
                                      //      bottom: size.height * 0.03),
                                      //  child: Text(
                                      //    formattedUpdate,
                                      //    style: const TextStyle(
                                      //      color: Colors.white,
                                      //      fontSize: 12,
                                      //    ),
                                      //  ),
                                      //),
                                      //Container(
                                      //  padding: EdgeInsets.symmetric(
                                      //      vertical: size.height * 0.01),
                                      //  child: Row(
                                      //    children: const [
                                      //      DaysAfter(
                                      //        dia: 'Ter',
                                      //        max: '12º',
                                      //        min: '25º',
                                      //        icon: WeatherIcons.day_sunny,
                                      //      ),
                                      //      DaysAfter(
                                      //        dia: 'Qua',
                                      //        max: '12º',
                                      //        min: '25º',
                                      //        icon: WeatherIcons.day_sunny,
                                      //      ),
                                      //      DaysAfter(
                                      //        dia: 'Qui',
                                      //        max: '12º',
                                      //        min: '25º',
                                      //        icon: WeatherIcons.day_sunny,
                                      //      ),
                                      //    ],
                                      //  ),
                                      //)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class DaysAfter extends StatelessWidget {
  const DaysAfter(
      {Key? key,
      required this.dia,
      required this.max,
      required this.min,
      required this.icon})
      : super(key: key);

  final String dia;
  final String max;
  final String min;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.02),
      child: Column(
        children: [
          Text(
            dia,
            style: const TextStyle(color: Colors.white),
          ),
          BoxedIcon(
            icon,
            color: Colors.white,
          ),
          Text(
            '$maxº/$minº',
            style:
                const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
          ),
        ],
      ),
    );
  }
}
