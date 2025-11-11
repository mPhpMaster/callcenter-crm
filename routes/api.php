<?php

use App\Http\Controllers\LeadController;
use Illuminate\Support\Facades\Route;

Route::prefix('leads')->group(function () {
    Route::get('/', [LeadController::class, 'index']);
    Route::get('/clients', [LeadController::class, 'clients']);
    Route::post('/import', [LeadController::class, 'import']);
    Route::post('/{id}/convert', [LeadController::class, 'convert']);
    Route::post('/{id}/note', [LeadController::class, 'addNote']);
    Route::get('/{id}', [LeadController::class, 'show']);
});
