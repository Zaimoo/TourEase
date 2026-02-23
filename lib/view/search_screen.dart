import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user.dart';
import '../models/destination.dart';
import '../services/use_firebase.dart';
import '../widgets/destination_card.dart';

class SearchScreen extends StatefulWidget {
  final AppUser? currentUser;
  final LatLng? userLocation;

  const SearchScreen({
    super.key,
    required this.currentUser,
    required this.userLocation,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final destinationsService = UseFirebase<Destination>(
    fromJson: (data, id) => Destination.fromJson(data, id),
    toJson: (dest) => dest.toJson(),
  );

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  List<Destination> _allDestinations = [];
  List<Destination> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  // Category filter
  String? _selectedCategory;
  final List<String> _categories = [
    'Natural Wonders',
    'Cultural',
    'Recreational',
    'Entertainment',
  ];

  @override
  void initState() {
    super.initState();
    _fetchAllDestinations();
    // Auto-focus search bar when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchAllDestinations() async {
    try {
      final destinations = await destinationsService.getAll('destinations');
      setState(() {
        _allDestinations = destinations;
        _searchResults = destinations; // Show all initially
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching destinations: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });

    if (query.isEmpty) {
      setState(() {
        _searchResults = _allDestinations;
      });
      return;
    }

    // Debounce search for 300ms
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    final lowercaseQuery = query.toLowerCase();

    var filtered = _allDestinations.where((dest) {
      final nameMatch = dest.name.toLowerCase().contains(lowercaseQuery);
      final shortDescMatch =
          dest.shortDescription.toLowerCase().contains(lowercaseQuery);
      final longDescMatch =
          dest.longDescription.toLowerCase().contains(lowercaseQuery);
      final addressMatch = dest.address.toLowerCase().contains(lowercaseQuery);

      return nameMatch || shortDescMatch || longDescMatch || addressMatch;
    }).toList();

    // Apply category filter if selected
    if (_selectedCategory != null) {
      filtered = filtered
          .where((dest) =>
              dest.category.toLowerCase() == _selectedCategory!.toLowerCase())
          .toList();
    }

    setState(() {
      _searchResults = filtered;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
      _selectedCategory = null;
      _searchResults = _allDestinations;
    });
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategory == category) {
        _selectedCategory = null;
      } else {
        _selectedCategory = category;
      }
    });
    // Re-run search with new filter
    if (_searchQuery.isNotEmpty) {
      _performSearch(_searchQuery);
    } else {
      // Filter all destinations by category
      if (_selectedCategory != null) {
        setState(() {
          _searchResults = _allDestinations
              .where((dest) =>
                  dest.category.toLowerCase() ==
                  _selectedCategory!.toLowerCase())
              .toList();
        });
      } else {
        setState(() {
          _searchResults = _allDestinations;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB6DCFE),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search destinations...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[600]),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black),
              onPressed: _clearSearch,
            ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Chips
          Container(
            color: const Color(0xFFB6DCFE),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (_) => _toggleCategory(category),
                      backgroundColor: Colors.white,
                      selectedColor: Colors.blue[300],
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Results Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isSearching
                      ? 'Search Results'
                      : _selectedCategory != null
                          ? '$_selectedCategory Places'
                          : 'All Destinations',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${_searchResults.length} ${_searchResults.length == 1 ? 'place' : 'places'}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Results List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.lightBlue,
                    ),
                  )
                : _searchResults.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final dest = _searchResults[index];
                          return DestinationCard(
                            currentUser: widget.currentUser,
                            name: dest.name,
                            shortDescription: dest.shortDescription,
                            longDescription: dest.longDescription,
                            imageUrl: dest.imageUrl,
                            openHours: dest.openHours,
                            rating: (dest.rating as num).toDouble(),
                            entranceFee: (dest.entranceFee as num).toDouble(),
                            fareCost: (dest.fareCost as num).toDouble(),
                            coordinates: LatLng(
                              dest.coordinates.latitude,
                              dest.coordinates.longitude,
                            ),
                            userLocation:
                                widget.userLocation ?? const LatLng(0, 0),
                            showMeta: true,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching
                ? 'No results found for "$_searchQuery"'
                : 'No destinations in this category',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_isSearching || _selectedCategory != null)
            TextButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }
}
