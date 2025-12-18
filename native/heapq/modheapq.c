/*
 * modheapq - Native heapq module for ucharm
 *
 * Provides heap queue (priority queue) functions.
 * This module replaces MicroPython's built-in heapq to add missing functions.
 *
 * Usage in Python:
 *   import heapq
 *   heapq.heappush(heap, item)
 *   item = heapq.heappop(heap)
 *   heapq.heapreplace(heap, item)
 *   largest = heapq.nlargest(3, items)
 */

#include "../bridge/mpy_bridge.h"
#include <string.h>

// ============================================================================
// Helper functions for heap operations
// ============================================================================

// Compare two Python objects (returns -1, 0, or 1)
static int compare_objs(mp_obj_t a, mp_obj_t b) {
    if (mp_obj_is_small_int(a) && mp_obj_is_small_int(b)) {
        mp_int_t ia = MP_OBJ_SMALL_INT_VALUE(a);
        mp_int_t ib = MP_OBJ_SMALL_INT_VALUE(b);
        return (ia > ib) - (ia < ib);
    }
    // Use rich comparison for other types
    if (mp_obj_is_true(mp_binary_op(MP_BINARY_OP_LESS, a, b))) {
        return -1;
    }
    if (mp_obj_is_true(mp_binary_op(MP_BINARY_OP_LESS, b, a))) {
        return 1;
    }
    return 0;
}

// Sift down operation for heap
static void sift_down(mp_obj_t *items, size_t len, size_t pos) {
    size_t child;
    mp_obj_t item = items[pos];
    
    while ((child = 2 * pos + 1) < len) {
        // Find smaller child
        size_t right = child + 1;
        if (right < len && compare_objs(items[right], items[child]) < 0) {
            child = right;
        }
        
        // If item is smaller than smallest child, we're done
        if (compare_objs(item, items[child]) <= 0) {
            break;
        }
        
        // Move child up
        items[pos] = items[child];
        pos = child;
    }
    items[pos] = item;
}

// Sift up operation for heap
static void sift_up(mp_obj_t *items, size_t pos) {
    mp_obj_t item = items[pos];
    
    while (pos > 0) {
        size_t parent = (pos - 1) / 2;
        if (compare_objs(items[parent], item) <= 0) {
            break;
        }
        items[pos] = items[parent];
        pos = parent;
    }
    items[pos] = item;
}

// ============================================================================
// heapq functions
// ============================================================================

// heapq.heappush(heap, item) -> None
MPY_FUNC_2(heapq, heappush) {
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(arg0, &len, &items);
    
    // Append item to list
    mp_obj_list_append(arg0, arg1);
    
    // Get new items pointer (may have changed due to realloc)
    mp_obj_list_get(arg0, &len, &items);
    
    // Sift up the new item
    sift_up(items, len - 1);
    
    return mp_const_none;
}
MPY_FUNC_OBJ_2(heapq, heappush);

// heapq.heappop(heap) -> item
MPY_FUNC_1(heapq, heappop) {
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(arg0, &len, &items);
    
    if (len == 0) {
        mp_raise_msg(&mp_type_IndexError, MP_ERROR_TEXT("index out of range"));
    }
    
    mp_obj_t result = items[0];
    
    if (len > 1) {
        // Move last item to root and sift down
        items[0] = items[len - 1];
    }
    
    // Remove last item by reducing list length
    mp_obj_list_set_len(arg0, len - 1);
    
    if (len > 1) {
        // Get updated items pointer and sift down
        mp_obj_list_get(arg0, &len, &items);
        sift_down(items, len, 0);
    }
    
    return result;
}
MPY_FUNC_OBJ_1(heapq, heappop);

// heapq.heapify(x) -> None
MPY_FUNC_1(heapq, heapify) {
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(arg0, &len, &items);
    
    // Sift down from last parent to root
    for (int i = (int)(len / 2) - 1; i >= 0; i--) {
        sift_down(items, len, (size_t)i);
    }
    
    return mp_const_none;
}
MPY_FUNC_OBJ_1(heapq, heapify);

// heapq.heapreplace(heap, item) -> old_item
// Pop and return smallest, then push new item (more efficient than heappop + heappush)
MPY_FUNC_2(heapq, heapreplace) {
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(arg0, &len, &items);
    
    if (len == 0) {
        mp_raise_msg(&mp_type_IndexError, MP_ERROR_TEXT("index out of range"));
    }
    
    mp_obj_t result = items[0];
    items[0] = arg1;
    sift_down(items, len, 0);
    
    return result;
}
MPY_FUNC_OBJ_2(heapq, heapreplace);

// heapq.heappushpop(heap, item) -> smallest
// Push item, then pop and return smallest (more efficient than heappush + heappop)
MPY_FUNC_2(heapq, heappushpop) {
    size_t len;
    mp_obj_t *items;
    mp_obj_list_get(arg0, &len, &items);
    
    // If heap is empty or item is smaller than root, just return item
    if (len == 0 || compare_objs(arg1, items[0]) <= 0) {
        return arg1;
    }
    
    // Otherwise, replace root with item and return old root
    mp_obj_t result = items[0];
    items[0] = arg1;
    sift_down(items, len, 0);
    
    return result;
}
MPY_FUNC_OBJ_2(heapq, heappushpop);

// heapq.nlargest(n, iterable) -> list
MPY_FUNC_2(heapq, nlargest) {
    size_t n = (size_t)mpy_int(arg0);
    
    // Get items from iterable
    size_t len;
    mp_obj_t *items;
    mp_obj_get_array(arg1, &len, &items);
    
    if (n == 0 || len == 0) {
        return mp_obj_new_list(0, NULL);
    }
    
    if (n >= len) {
        // Return sorted copy (descending)
        mp_obj_t result = mp_obj_new_list(len, items);
        // Sort in place (ascending)
        mp_obj_list_sort(1, &result, (mp_map_t*)&mp_const_empty_map);
        // Reverse for descending
        size_t result_len;
        mp_obj_t *result_items;
        mp_obj_list_get(result, &result_len, &result_items);
        for (size_t i = 0; i < result_len / 2; i++) {
            mp_obj_t tmp = result_items[i];
            result_items[i] = result_items[result_len - 1 - i];
            result_items[result_len - 1 - i] = tmp;
        }
        return result;
    }
    
    // Build a min-heap of size n with first n elements
    mp_obj_t heap = mp_obj_new_list(n, items);
    size_t heap_len;
    mp_obj_t *heap_items;
    mp_obj_list_get(heap, &heap_len, &heap_items);
    
    // Heapify
    for (int i = (int)(n / 2) - 1; i >= 0; i--) {
        sift_down(heap_items, n, (size_t)i);
    }
    
    // Process remaining items
    for (size_t i = n; i < len; i++) {
        if (compare_objs(items[i], heap_items[0]) > 0) {
            heap_items[0] = items[i];
            sift_down(heap_items, n, 0);
        }
    }
    
    // Sort result (descending)
    mp_obj_list_sort(1, &heap, (mp_map_t*)&mp_const_empty_map);
    mp_obj_list_get(heap, &heap_len, &heap_items);
    for (size_t i = 0; i < heap_len / 2; i++) {
        mp_obj_t tmp = heap_items[i];
        heap_items[i] = heap_items[heap_len - 1 - i];
        heap_items[heap_len - 1 - i] = tmp;
    }
    
    return heap;
}
MPY_FUNC_OBJ_2(heapq, nlargest);

// heapq.nsmallest(n, iterable) -> list
MPY_FUNC_2(heapq, nsmallest) {
    size_t n = (size_t)mpy_int(arg0);
    
    // Get items from iterable
    size_t len;
    mp_obj_t *items;
    mp_obj_get_array(arg1, &len, &items);
    
    if (n == 0 || len == 0) {
        return mp_obj_new_list(0, NULL);
    }
    
    if (n >= len) {
        // Return sorted copy (ascending)
        mp_obj_t result = mp_obj_new_list(len, items);
        mp_obj_list_sort(1, &result, (mp_map_t*)&mp_const_empty_map);
        return result;
    }
    
    // Simple approach: sort and take first n
    mp_obj_t sorted_list = mp_obj_new_list(len, items);
    mp_obj_list_sort(1, &sorted_list, (mp_map_t*)&mp_const_empty_map);
    
    size_t sorted_len;
    mp_obj_t *sorted_items;
    mp_obj_list_get(sorted_list, &sorted_len, &sorted_items);
    
    return mp_obj_new_list(n, sorted_items);
}
MPY_FUNC_OBJ_2(heapq, nsmallest);

// ============================================================================
// Module Definition
// ============================================================================

MPY_MODULE_BEGIN(heapq)
    MPY_MODULE_FUNC(heapq, heappush)
    MPY_MODULE_FUNC(heapq, heappop)
    MPY_MODULE_FUNC(heapq, heapify)
    MPY_MODULE_FUNC(heapq, heapreplace)
    MPY_MODULE_FUNC(heapq, heappushpop)
    MPY_MODULE_FUNC(heapq, nlargest)
    MPY_MODULE_FUNC(heapq, nsmallest)
MPY_MODULE_END(heapq)
