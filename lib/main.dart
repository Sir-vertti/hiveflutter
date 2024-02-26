import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'main.g.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MovieAdapter()); // Registro del adaptador aquí
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Películas Populares',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const PopularMoviesPage(),
    );
  }
}

class PopularMoviesPage extends StatefulWidget {
  const PopularMoviesPage({Key? key}) : super(key: key);

  @override
  _PopularMoviesPageState createState() => _PopularMoviesPageState();
}

class _PopularMoviesPageState extends State<PopularMoviesPage> {
  late List<Movie> movies;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    movies = [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Películas Populares'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              if (!_isLoading) {
                fetchPopularMovies();
              }
            },
            child: const Text('Mostrarme'),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : ListView.builder(
                    itemCount: movies.length,
                    itemBuilder: (BuildContext context, int index) {
                      return MovieListItem(movie: movies[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> fetchPopularMovies() async {
    setState(() {
      _isLoading = true;
    });

    final box = await Hive.openBox<Movie>('movies');
    final List<Movie> storedMovies = box.values.toList();

    if (storedMovies.isNotEmpty) {
      setState(() {
        movies = storedMovies;
        _isLoading = false;
      });
    } else {
      await fetchPopularMoviesFromApi();
    }
  }

  Future<void> fetchPopularMoviesFromApi() async {
    final response = await http.get(
      Uri.parse(
          'https://api.themoviedb.org/3/movie/popular?api_key=dd9c5200c1cbc0ad07bc8e2534c75b6f&language=en-US&page=1'),
    );

    if (response.statusCode == 200) {
      final parsed = jsonDecode(response.body);
      final List<Movie> moviesList =
          List<Movie>.from(parsed['results'].map((x) => Movie.fromJson(x)));

      final box = await Hive.openBox<Movie>('movies');
      await box.clear();
      await box.addAll(moviesList);

      setState(() {
        movies = moviesList;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      throw Exception('Failed to load movies');
    }
  }
}

@HiveType(typeId: 0)
class Movie extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String overview;

  @HiveField(3)
  final String posterPath;

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'],
      overview: json['overview'],
      posterPath: json['poster_path'],
    );
  }
}

class MovieListItem extends StatelessWidget {
  final Movie movie;

  const MovieListItem({Key? key, required this.movie}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Image.network(
        'https://image.tmdb.org/t/p/w185${movie.posterPath}',
        width: 100,
      ),
      title: Text(movie.title),
      subtitle: Text(
        movie.overview.length > 50
            ? '${movie.overview.substring(0, 50)}...'
            : movie.overview,
      ),
    );
  }
}
