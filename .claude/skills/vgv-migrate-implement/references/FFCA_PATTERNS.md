# FFCA Patterns Reference

Canonical code templates for Feature-First Clean Architecture. Sub-agents use these as the source of truth for generated code structure. When in doubt, follow these patterns exactly.

---

## Dependency graph (reminder)

```
Presentation  →  Domain  ←  Data
```

- Presentation depends on Domain only (never on Data directly)
- Data depends on Domain only
- Domain depends on nothing in the feature graph (may depend on other feature domains)
- Shared packages are dependencies of both Data and Presentation

---

## 1. Domain layer patterns

### 1.1 Domain model

```dart
// lib/models/product.dart

/// Represents a product in the catalog.
class Product {
  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final String? imageUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          price == other.price &&
          imageUrl == other.imageUrl;

  @override
  int get hashCode => Object.hash(id, title, description, price, imageUrl);

  @override
  String toString() =>
      'Product(id: $id, title: $title, description: $description, '
      'price: $price, imageUrl: $imageUrl)';
}
```

### 1.2 Repository interface

```dart
// lib/repositories/i_products_repository.dart

/// Contract for persisting and retrieving [Product] data.
abstract interface class IProductsRepository {
  Future<Product> getProductById(String productId);
  Future<List<Product>> getProducts();
  Stream<Product> watchProductById(String productId);
  Future<void> saveProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String productId);
}
```

### 1.3 Query use case (Future)

```dart
// lib/use_cases/get_cart_by_id_query.dart

/// Assembles a [Cart] by combining data from [ICartsRepository]
/// and [IProductsRepository].
///
/// Only create a Query class when logic spans multiple repositories.
/// Single-repository reads belong directly in the BLoC.
class GetCartByIdQuery {
  const GetCartByIdQuery({
    required ICartsRepository cartsRepository,
    required IProductsRepository productsRepository,
  })  : _cartsRepository = cartsRepository,
        _productsRepository = productsRepository;

  final ICartsRepository _cartsRepository;
  final IProductsRepository _productsRepository;

  Future<Cart> get(String cartId) async {
    final summary = await _cartsRepository.getCartById(cartId);
    return Cart(
      id: summary.id,
      products: [
        for (final id in summary.productIds)
          await _productsRepository.getProductById(id),
      ],
    );
  }
}
```

### 1.4 Query use case (Stream)

```dart
// lib/use_cases/watch_current_user_profile_query.dart

class WatchCurrentUserProfileQuery {
  const WatchCurrentUserProfileQuery({
    required IAuthRepository authRepository,
    required IUserProfilesRepository userProfilesRepository,
  })  : _authRepository = authRepository,
        _userProfilesRepository = userProfilesRepository;

  final IAuthRepository _authRepository;
  final IUserProfilesRepository _userProfilesRepository;

  Stream<UserProfile?> watch() {
    return _authRepository.watchCurrentUser().switchMap((authUser) {
      if (authUser == null) return Stream.value(null);
      return _userProfilesRepository.watchUserProfile(authUser.id);
    });
  }
}
```

### 1.5 Command use case

```dart
// lib/use_cases/update_product_title_command.dart

class UpdateProductTitleCommand {
  const UpdateProductTitleCommand({
    required IProductsRepository productsRepository,
  }) : _productsRepository = productsRepository;

  final IProductsRepository _productsRepository;

  Future<void> execute({
    required String productId,
    required String newTitle,
  }) async {
    final product = await _productsRepository.getProductById(productId);
    await _productsRepository.updateProduct(
      Product(
        id: product.id,
        title: newTitle,
        description: product.description,
        price: product.price,
        imageUrl: product.imageUrl,
      ),
    );
  }
}
```

### 1.6 Summary pattern (cross-feature storage)

```dart
// lib/models/cart_summary.dart  — what is stored in cart_data

/// Stored representation of a cart. Contains product IDs only.
/// Use [GetCartByIdQuery] to assemble a fully populated [Cart].
class CartSummary {
  const CartSummary({
    required this.id,
    required this.productIds,
  });

  final String id;
  final List<String> productIds;
}

// lib/models/cart.dart  — what is returned by the use case

/// Fully populated cart with [Product] objects.
class Cart {
  const Cart({
    required this.id,
    required this.products,
  });

  final String id;
  final List<Product> products;
}
```

---

## 2. Data layer patterns

### 2.0 Pre-generated client check (always run first)

Before generating any data layer code, check whether a Swagger-generated client package covers the feature's endpoints. The generated packages live under `shared/` and are named after the API version (e.g. `{project}_api_v2`, `{project}_api_v3`, where `{project}` is the manifest's `project_name`).

```
shared/
├── {project}_api_v2/   ← covers /v2/ endpoints; DTOs and methods already generated
└── {project}_api_v3/   ← covers /v3/ endpoints; DTOs and methods already generated
```

If a generated client covers the required endpoints:
- **Do not** create a `data_sources/` directory or any DTOs
- **Do** write a mapper from the generated DTO class to the domain model
- **Do** write the repository implementation injecting the generated client directly

If no generated client exists for the required endpoints, fall back to the manual patterns in sections 2.3–2.6.

### 2.1 Mapper (with pre-generated client — primary pattern)

```dart
// lib/mappers/product_mapper.dart

import 'package:product_domain/product_domain.dart';
import 'package:{project}_api_v2/{project}_api_v2.dart';  // generated

// The generated DTO class name may differ from the domain model name.
// Check the generated package's barrel file for the exact class name.
extension ProductResponseMapper on ProductResponse {
  Product toDomain() {
    return Product(
      id: id,
      title: name,          // field names may differ — map explicitly
      description: description ?? '',
      price: price.toDouble(),
      imageUrl: imageUrl,
    );
  }
}
```

### 2.2 Repository implementation (with pre-generated client — primary pattern)

```dart
// lib/repositories/products_repository.dart

import 'package:product_domain/product_domain.dart';
import 'package:{project}_api_v2/{project}_api_v2.dart';
import '../mappers/product_mapper.dart';

class ProductsRepository implements IProductsRepository {
  const ProductsRepository({required {Project}ApiV2 apiClient})
      : _apiClient = apiClient;

  final {Project}ApiV2 _apiClient;

  @override
  Future<Product> getProductById(String productId) async {
    final response = await _apiClient.getProduct(id: productId);
    return response.toDomain();
  }

  @override
  Future<List<Product>> getProducts() async {
    final responses = await _apiClient.listProducts();
    return responses.map((r) => r.toDomain()).toList();
  }

  // Stub for endpoints not yet in the generated client:
  @override
  Future<void> saveProduct(Product product) async {
    // TODO(vgv-migrate-implement): [product_data] ProductsRepository.saveProduct
    // Reason: no matching endpoint found in {project}_api_v2 barrel exports.
    // Action: add endpoint to API spec, regenerate client, then implement.
    throw UnimplementedError('saveProduct is not yet implemented.');
  }
}
```

### 2.3 DTO (fallback — only when no generated client covers the endpoint)

```dart
// lib/data_sources/products_remote_data_source/dtos/product_dto.dart

import 'package:json_annotation/json_annotation.dart';

part 'product_dto.g.dart';

@JsonSerializable()
class ProductDto {
  const ProductDto({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.imageUrl,
  });

  factory ProductDto.fromJson(Map<String, dynamic> json) =>
      _$ProductDtoFromJson(json);

  final String id;
  final String title;
  final String description;
  final double price;
  @JsonKey(name: 'image_url')
  final String? imageUrl;

  Map<String, dynamic> toJson() => _$ProductDtoToJson(this);
}
```

### 2.4 Mapper (fallback — with manual DTO)

```dart
// lib/mappers/product_mapper.dart

import 'package:product_domain/product_domain.dart';
import '../data_sources/products_remote_data_source/dtos/product_dto.dart';

extension ProductDtoMapper on ProductDto {
  Product toDomain() {
    return Product(
      id: id,
      title: title,
      description: description,
      price: price,
      imageUrl: imageUrl,
    );
  }
}
```

### 2.5 Remote data source (fallback — only when no generated client exists)

```dart
// lib/data_sources/products_remote_data_source/products_remote_data_source.dart

import 'package:{project}_api_client/{project}_api_client.dart';
import 'dtos/product_dto.dart';

class ProductsRemoteDataSource {
  const ProductsRemoteDataSource({required {Project}ApiClient apiClient})
      : _apiClient = apiClient;

  final {Project}ApiClient _apiClient;

  Future<ProductDto> getProductById(String id) async {
    final response = await _apiClient.getProduct(id: id);
    return ProductDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ProductDto>> getProducts() async {
    final response = await _apiClient.listProducts();
    final list = response.data as List<dynamic>;
    return list
        .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

### 2.6 Repository implementation (fallback — with manual data source)

```dart
// lib/repositories/products_repository.dart

import 'package:product_domain/product_domain.dart';
import '../data_sources/products_remote_data_source/products_remote_data_source.dart';
import '../mappers/product_mapper.dart';

class ProductsRepository implements IProductsRepository {
  const ProductsRepository({
    required ProductsRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final ProductsRemoteDataSource _remoteDataSource;

  @override
  Future<Product> getProductById(String productId) async {
    final dto = await _remoteDataSource.getProductById(productId);
    return dto.toDomain();
  }

  @override
  Future<List<Product>> getProducts() async {
    final dtos = await _remoteDataSource.getProducts();
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  // TODO: implement remaining interface methods or mark UnimplementedError
  @override
  Stream<Product> watchProductById(String productId) {
    // TODO(vgv-migrate-implement): [product_data] watchProductById
    // Reason: no WebSocket/SSE endpoint found in manifest for this method.
    // Action: implement if real-time updates are needed, or remove from interface.
    throw UnimplementedError('watchProductById is not yet implemented.');
  }

  @override
  Future<void> saveProduct(Product product) async {
    throw UnimplementedError('saveProduct is not yet implemented.');
  }

  @override
  Future<void> updateProduct(Product product) async {
    throw UnimplementedError('updateProduct is not yet implemented.');
  }

  @override
  Future<void> deleteProduct(String productId) async {
    throw UnimplementedError('deleteProduct is not yet implemented.');
  }
}
```

### 2.5 Nested API object normalization

When an API response embeds a foreign model (e.g., `ApiPhoto` contains an `ApiUser`):

```dart
// In photos_data — normalize at repository level, NOT via a use case.
// Duplicate the user mapper here rather than importing users_data.

class PhotosRepository implements IPhotosRepository {
  const PhotosRepository({
    required SwaggerRemoteDataSource remoteDataSource,
    required PhotosLocalDataSource photosDataSource,
    required IUsersRepository usersRepository,
  })  : _remoteDataSource = remoteDataSource,
        _photosLocalDataSource = photosDataSource,
        _usersRepo = usersRepository;

  @override
  Future<PhotoSummary> fetchPhotoById(String id) async {
    final apiPhoto = await _remoteDataSource.getPhotoById(id);

    // Map embedded user and save via the users repository interface.
    // The mapper is duplicated here intentionally (bounded context trade-off).
    final userDomain = User(id: apiPhoto.user.id, name: apiPhoto.user.name);
    await _usersRepo.saveUser(userDomain);

    return PhotoSummary(id: apiPhoto.id, userId: apiPhoto.user.id);
  }
}
```

---

## 3. Presentation layer patterns

### 3.1 Cubit + state (simple)

```dart
// lib/product_detail/bloc/product_detail_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:product_domain/product_domain.dart';
import 'product_detail_state.dart';

class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductDetailCubit({
    required IProductsRepository productsRepository,
  })  : _productsRepository = productsRepository,
        super(const ProductDetailInitial());

  final IProductsRepository _productsRepository;

  Future<void> loadProduct(String productId) async {
    emit(const ProductDetailLoading());
    try {
      final product = await _productsRepository.getProductById(productId);
      emit(ProductDetailLoaded(product: product));
    } catch (e, st) {
      addError(e, st);
      emit(ProductDetailError(message: e.toString()));
    }
  }
}
```

```dart
// lib/product_detail/bloc/product_detail_state.dart

import 'package:equatable/equatable.dart';
import 'package:product_domain/product_domain.dart';

sealed class ProductDetailState extends Equatable {
  const ProductDetailState();
}

final class ProductDetailInitial extends ProductDetailState {
  const ProductDetailInitial();
  @override
  List<Object?> get props => [];
}

final class ProductDetailLoading extends ProductDetailState {
  const ProductDetailLoading();
  @override
  List<Object?> get props => [];
}

final class ProductDetailLoaded extends ProductDetailState {
  const ProductDetailLoaded({required this.product});
  final Product product;
  @override
  List<Object?> get props => [product];
}

final class ProductDetailError extends ProductDetailState {
  const ProductDetailError({required this.message});
  final String message;
  @override
  List<Object?> get props => [message];
}
```

### 3.2 BLoC + events (complex)

```dart
// lib/cart/bloc/cart_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cart_domain/cart_domain.dart';
import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc({required ICartsRepository cartsRepository})
      : _cartsRepository = cartsRepository,
        super(const CartInitial()) {
    on<CartLoadRequested>(_onLoadRequested);
    on<CartItemAdded>(_onItemAdded);
    on<CartItemRemoved>(_onItemRemoved);
  }

  final ICartsRepository _cartsRepository;

  Future<void> _onLoadRequested(
    CartLoadRequested event,
    Emitter<CartState> emit,
  ) async {
    emit(const CartLoading());
    try {
      final cart = await _cartsRepository.getCartById(event.cartId);
      emit(CartLoaded(cart: cart));
    } catch (e, st) {
      addError(e, st);
      emit(CartError(message: e.toString()));
    }
  }

  Future<void> _onItemAdded(
    CartItemAdded event,
    Emitter<CartState> emit,
  ) async {
    // ...
  }

  Future<void> _onItemRemoved(
    CartItemRemoved event,
    Emitter<CartState> emit,
  ) async {
    // ...
  }
}
```

```dart
// lib/cart/bloc/cart_event.dart

import 'package:equatable/equatable.dart';

sealed class CartEvent extends Equatable {
  const CartEvent();
}

final class CartLoadRequested extends CartEvent {
  const CartLoadRequested({required this.cartId});
  final String cartId;
  @override
  List<Object?> get props => [cartId];
}

final class CartItemAdded extends CartEvent {
  const CartItemAdded({required this.productId});
  final String productId;
  @override
  List<Object?> get props => [productId];
}

final class CartItemRemoved extends CartEvent {
  const CartItemRemoved({required this.productId});
  final String productId;
  @override
  List<Object?> get props => [productId];
}
```

### 3.3 Screen widget

```dart
// lib/product_detail/views/product_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui_kit/ui_kit.dart';
import '../bloc/product_detail_cubit.dart';
import '../bloc/product_detail_state.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({required this.productId, super.key});

  static const routeName = '/product-detail';

  final String productId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailCubit, ProductDetailState>(
      builder: (context, state) {
        return switch (state) {
          ProductDetailInitial() => const SizedBox.shrink(),
          ProductDetailLoading() => const ScLoadingIndicator(),
          ProductDetailLoaded(:final product) => _ProductDetailBody(
              product: product,
            ),
          ProductDetailError(:final message) => ScErrorView(message: message),
        };
      },
    );
  }
}

class _ProductDetailBody extends StatelessWidget {
  const _ProductDetailBody({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ScAppBar(title: product.title),
      body: Column(
        children: [
          Text(product.description),
          Text('\$${product.price}'),
        ],
      ),
    );
  }
}
```

### 3.4 Module file

```dart
// lib/product_detail/product_detail_module.dart

export 'bloc/product_detail_cubit.dart';
export 'bloc/product_detail_state.dart';
export 'views/product_detail_screen.dart';
```

### 3.5 Presentation barrel

```dart
// lib/product_presentation.dart

export 'product_detail/product_detail_module.dart';
export 'product_list/product_list_module.dart';
```

---

## 4. Test patterns

### 4.1 Domain model test

```dart
// test/models/product_test.dart

import 'package:test/test.dart';
import 'package:product_domain/product_domain.dart';

void main() {
  group('Product', () {
    const product = Product(
      id: '1',
      title: 'Test Product',
      description: 'A test product.',
      price: 9.99,
    );

    test('supports value equality', () {
      expect(
        product,
        equals(
          const Product(
            id: '1',
            title: 'Test Product',
            description: 'A test product.',
            price: 9.99,
          ),
        ),
      );
    });

    test('hashCode is consistent with equality', () {
      const same = Product(
        id: '1',
        title: 'Test Product',
        description: 'A test product.',
        price: 9.99,
      );
      expect(product.hashCode, equals(same.hashCode));
    });

    test('toString contains field values', () {
      expect(product.toString(), contains('Test Product'));
    });
  });
}
```

### 4.2 Data mapper test

```dart
// test/mappers/product_mapper_test.dart

import 'package:test/test.dart';
import 'package:product_data/src/mappers/product_mapper.dart';
import 'package:product_data/src/data_sources/products_remote_data_source/dtos/product_dto.dart';

void main() {
  group('ProductDtoMapper', () {
    test('toDomain maps all fields correctly', () {
      const dto = ProductDto(
        id: '1',
        title: 'Test',
        description: 'Desc',
        price: 9.99,
        imageUrl: 'https://example.com/img.png',
      );

      final domain = dto.toDomain();

      expect(domain.id, equals('1'));
      expect(domain.title, equals('Test'));
      expect(domain.description, equals('Desc'));
      expect(domain.price, equals(9.99));
      expect(domain.imageUrl, equals('https://example.com/img.png'));
    });

    test('toDomain handles null imageUrl', () {
      const dto = ProductDto(
        id: '1',
        title: 'Test',
        description: 'Desc',
        price: 9.99,
      );
      expect(dto.toDomain().imageUrl, isNull);
    });
  });
}
```

### 4.3 Repository test

```dart
// test/repositories/products_repository_test.dart

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:product_data/product_data.dart';
import 'package:product_domain/product_domain.dart';

class MockProductsRemoteDataSource extends Mock
    implements ProductsRemoteDataSource {}

void main() {
  late MockProductsRemoteDataSource mockDataSource;
  late ProductsRepository repository;

  setUp(() {
    mockDataSource = MockProductsRemoteDataSource();
    repository = ProductsRepository(remoteDataSource: mockDataSource);
  });

  group('ProductsRepository', () {
    group('getProductById', () {
      const dto = ProductDto(
        id: '1',
        title: 'Test',
        description: 'Desc',
        price: 9.99,
      );

      test('returns mapped domain model on success', () async {
        when(() => mockDataSource.getProductById('1'))
            .thenAnswer((_) async => dto);

        final result = await repository.getProductById('1');

        expect(result.id, equals('1'));
        expect(result.title, equals('Test'));
        verify(() => mockDataSource.getProductById('1')).called(1);
      });

      test('propagates exception from data source', () async {
        when(() => mockDataSource.getProductById(any()))
            .thenThrow(Exception('network error'));

        expect(
          () => repository.getProductById('1'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
```

### 4.4 Cubit test

```dart
// test/product_detail/bloc/product_detail_cubit_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:product_domain/product_domain.dart';
import 'package:product_presentation/product_presentation.dart';

class MockProductsRepository extends Mock implements IProductsRepository {}

void main() {
  late MockProductsRepository mockRepository;

  const product = Product(
    id: '1',
    title: 'Test',
    description: 'Desc',
    price: 9.99,
  );

  setUp(() {
    mockRepository = MockProductsRepository();
  });

  group('ProductDetailCubit', () {
    blocTest<ProductDetailCubit, ProductDetailState>(
      'emits [loading, loaded] when loadProduct succeeds',
      build: () => ProductDetailCubit(productsRepository: mockRepository),
      setUp: () {
        when(() => mockRepository.getProductById('1'))
            .thenAnswer((_) async => product);
      },
      act: (cubit) => cubit.loadProduct('1'),
      expect: () => [
        const ProductDetailLoading(),
        const ProductDetailLoaded(product: product),
      ],
    );

    blocTest<ProductDetailCubit, ProductDetailState>(
      'emits [loading, error] when loadProduct throws',
      build: () => ProductDetailCubit(productsRepository: mockRepository),
      setUp: () {
        when(() => mockRepository.getProductById(any()))
            .thenThrow(Exception('network error'));
      },
      act: (cubit) => cubit.loadProduct('1'),
      expect: () => [
        const ProductDetailLoading(),
        isA<ProductDetailError>(),
      ],
    );
  });
}
```

### 4.5 Widget test helpers

```dart
// test/helpers/pump_app.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    List<BlocProvider> blocProviders = const [],
  }) {
    return pumpWidget(
      MultiBlocProvider(
        providers: blocProviders,
        child: MaterialApp(home: widget),
      ),
    );
  }
}
```

---

## 5. pubspec.yaml templates

### 5.1 Domain package

```yaml
name: {feature}_domain
description: Domain layer for the {feature} feature.
version: 0.1.0+1
publish_to: none

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  # cross-feature domain deps here

dev_dependencies:
  very_good_analysis: ^6.0.0
  test: ^1.25.0
```

> **Note:** Domain models use manual `==`/`hashCode`/`toString` (see pattern 1.1),
> so `equatable` is not needed in the domain package. Equatable is used in
> the presentation layer for state classes (see pattern 3.1).

### 5.2 Data package

```yaml
name: {feature}_data
description: Data layer for the {feature} feature.
version: 0.1.0+1
publish_to: none

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  {feature}_domain:
    path: ../{feature}_domain
  json_annotation: ^4.9.0
  # shared api client here

dev_dependencies:
  very_good_analysis: ^6.0.0
  build_runner: ^2.4.0
  json_serializable: ^6.8.0
  mocktail: ^1.0.0
  test: ^1.25.0
```

### 5.3 Presentation package

```yaml
name: {feature}_presentation
description: Presentation layer for the {feature} feature.
version: 0.1.0+1
publish_to: none

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter
  {feature}_domain:
    path: ../{feature}_domain
  flutter_bloc: ^8.1.0
  equatable: ^2.0.5
  ui_kit:
    path: ../../../shared/ui_kit

dev_dependencies:
  very_good_analysis: ^6.0.0
  bloc_test: ^9.1.0
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
```

---

## 6. Stub conventions (full reference)

### Missing cross-feature domain dep

```dart
// features/{feature}/{feature}_domain/lib/stubs/{dep}_domain_stub.dart

// TODO(vgv-migrate-implement): [{feature}_domain] {dep}_domain stub
// Reason: {dep}_domain not found in workspace at implementation time.
// Action: once {dep} feature is implemented, remove this stub and add
//   the real dependency to pubspec.yaml:
//   {dep}_domain:
//     path: ../../{dep}/{dep}_domain
// Then replace usages of I{Dep}RepositoryStub with the real interface.

// ignore_for_file: one_member_abstracts
abstract interface class I{Dep}RepositoryStub {
  // Add methods as {dep}_domain is defined.
}
```

### Missing shared API client method

```dart
Future<{ReturnDto}> {missingMethod}({params}) async {
  // TODO(vgv-migrate-implement): [{feature}_data] {ApiClient}.{missingMethod}
  // Reason: method not found in shared/{api_client} barrel exports at implementation time.
  // Action: add {missingMethod} to the shared api client,
  //   then replace this stub.
  throw UnimplementedError(
    '{ApiClient}.{missingMethod} is not yet implemented in the shared client.',
  );
}
```

### Missing ui_kit component

```dart
// TODO(vgv-migrate-implement): [{feature}_presentation] {ComponentName} not found in ui_kit
// Reason: {ComponentName} not found in ui_kit barrel exports at implementation time.
// Action: add {ComponentName} to ui_kit,
//   then replace this placeholder widget.
Container(
  color: const Color(0xFFFF0000),
  height: 48,
  child: const Text('{ComponentName} placeholder — replace with ui_kit widget'),
),
```
