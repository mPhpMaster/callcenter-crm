// ============================================
// LARAVEL BACKEND
// ============================================

// 1. DATABASE MIGRATION
// database/migrations/xxxx_create_leads_table.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('leads', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->nullable();
            $table->string('phone')->nullable();
            $table->string('company')->nullable();
            $table->text('notes')->nullable();
            $table->enum('status', ['lead', 'client'])->default('lead');
            $table->timestamp('converted_at')->nullable();
            $table->timestamps();
        });

        Schema::create('lead_history', function (Blueprint $table) {
            $table->id();
            $table->foreignId('lead_id')->constrained()->onDelete('cascade');
            $table->string('action');
            $table->text('details')->nullable();
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('lead_history');
        Schema::dropIfExists('leads');
    }
};

// 2. MODELS
// app/Models/Lead.php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Lead extends Model
{
    protected $fillable = [
        'name', 'email', 'phone', 'company', 'notes', 'status', 'converted_at'
    ];

    protected $casts = [
        'converted_at' => 'datetime',
    ];

    public function history()
    {
        return $this->hasMany(LeadHistory::class);
    }

    public function scopeLeads($query)
    {
        return $query->where('status', 'lead');
    }

    public function scopeClients($query)
    {
        return $query->where('status', 'client');
    }
}

// app/Models/LeadHistory.php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LeadHistory extends Model
{
    protected $table = 'lead_history';
    
    protected $fillable = [
        'lead_id', 'action', 'details'
    ];

    public function lead()
    {
        return $this->belongsTo(Lead::class);
    }
}

// 3. CONTROLLERS
// app/Http/Controllers/LeadController.php
<?php

namespace App\Http\Controllers;

use App\Models\Lead;
use App\Models\LeadHistory;
use Illuminate\Http\Request;
use Maatwebsite\Excel\Facades\Excel;
use App\Imports\LeadsImport;

class LeadController extends Controller
{
    public function index(Request $request)
    {
        $query = Lead::with('history')->leads();
        
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%")
                  ->orWhere('phone', 'like', "%{$search}%")
                  ->orWhere('company', 'like', "%{$search}%");
            });
        }

        return response()->json($query->latest()->get());
    }

    public function clients(Request $request)
    {
        $query = Lead::with('history')->clients();
        
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%")
                  ->orWhere('phone', 'like', "%{$search}%")
                  ->orWhere('company', 'like', "%{$search}%");
            });
        }

        return response()->json($query->latest()->get());
    }

    public function import(Request $request)
    {
        $request->validate([
            'file' => 'required|mimes:xlsx,xls,csv'
        ]);

        try {
            Excel::import(new LeadsImport, $request->file('file'));
            return response()->json(['message' => 'Leads imported successfully']);
        } catch (\Exception $e) {
            return response()->json(['error' => $e->getMessage()], 500);
        }
    }

    public function convert(Request $request, $id)
    {
        $request->validate([
            'note' => 'required|string'
        ]);

        $lead = Lead::findOrFail($id);
        $lead->status = 'client';
        $lead->converted_at = now();
        $lead->save();

        LeadHistory::create([
            'lead_id' => $lead->id,
            'action' => 'Converted to Client',
            'details' => $request->note
        ]);

        return response()->json([
            'message' => 'Lead converted to client successfully',
            'client' => $lead->load('history')
        ]);
    }

    public function addNote(Request $request, $id)
    {
        $request->validate([
            'note' => 'required|string'
        ]);

        $lead = Lead::findOrFail($id);

        LeadHistory::create([
            'lead_id' => $lead->id,
            'action' => 'Note Added',
            'details' => $request->note
        ]);

        return response()->json([
            'message' => 'Note added successfully',
            'lead' => $lead->load('history')
        ]);
    }

    public function show($id)
    {
        $lead = Lead::with('history')->findOrFail($id);
        return response()->json($lead);
    }
}

// 4. EXCEL IMPORT
// app/Imports/LeadsImport.php
<?php

namespace App\Imports;

use App\Models\Lead;
use App\Models\LeadHistory;
use Maatwebsite\Excel\Concerns\ToModel;
use Maatwebsite\Excel\Concerns\WithHeadingRow;

class LeadsImport implements ToModel, WithHeadingRow
{
    public function model(array $row)
    {
        $lead = Lead::create([
            'name' => $row['name'] ?? '',
            'email' => $row['email'] ?? null,
            'phone' => $row['phone'] ?? null,
            'company' => $row['company'] ?? null,
            'notes' => $row['notes'] ?? null,
            'status' => 'lead'
        ]);

        LeadHistory::create([
            'lead_id' => $lead->id,
            'action' => 'Lead Imported',
            'details' => 'Imported from Excel'
        ]);

        return $lead;
    }
}

// 5. ROUTES
// routes/api.php
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

// ============================================
// VUE.JS FRONTEND
// ============================================

// 6. MAIN VUE COMPONENT
// resources/js/components/CallCenterCRM.vue
<template>
  <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-6">
    <div class="max-w-7xl mx-auto">
      <div class="bg-white rounded-2xl shadow-2xl overflow-hidden">
        <!-- Header -->
        <div class="bg-gradient-to-r from-blue-600 to-indigo-600 p-6 text-white">
          <h1 class="text-3xl font-bold mb-2">Call Center CRM</h1>
          <p class="text-blue-100">Manage your leads and clients efficiently</p>
        </div>

        <!-- Import Section -->
        <div class="p-6 border-b bg-gray-50">
          <div class="flex items-center gap-4">
            <label class="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 cursor-pointer transition">
              <input
                type="file"
                @change="handleFileUpload"
                accept=".xlsx,.xls,.csv"
                class="hidden"
              />
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
              </svg>
              Import Excel
            </label>
            <span v-if="importing" class="text-gray-600">Importing...</span>
          </div>
        </div>

        <!-- Tabs and Search -->
        <div class="p-6 border-b">
          <div class="flex flex-wrap gap-4 items-center justify-between">
            <div class="flex gap-2">
              <button
                @click="activeTab = 'leads'"
                :class="[
                  'px-6 py-2 rounded-lg font-medium transition',
                  activeTab === 'leads'
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                ]"
              >
                Leads ({{ leads.length }})
              </button>
              <button
                @click="activeTab = 'clients'"
                :class="[
                  'px-6 py-2 rounded-lg font-medium transition',
                  activeTab === 'clients'
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                ]"
              >
                Clients ({{ clients.length }})
              </button>
            </div>

            <div class="relative flex-1 max-w-md">
              <input
                v-model="searchTerm"
                @input="handleSearch"
                type="text"
                placeholder="Search by name, email, phone, or company..."
                class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
              <svg class="w-5 h-5 absolute left-3 top-2.5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
          </div>
        </div>

        <!-- Leads Tab -->
        <div v-if="activeTab === 'leads'" class="p-6">
          <div v-if="leads.length === 0" class="text-center py-12 text-gray-500">
            <p class="text-lg">No leads found. Import leads from Excel to get started.</p>
          </div>

          <div v-else class="space-y-4">
            <div
              v-for="lead in leads"
              :key="lead.id"
              class="border border-gray-200 rounded-lg p-4 hover:shadow-lg transition"
            >
              <div class="flex justify-between items-start">
                <div class="flex-1">
                  <h3 class="text-xl font-semibold text-gray-800">{{ lead.name }}</h3>
                  <div class="mt-2 space-y-1 text-gray-600">
                    <p v-if="lead.email"><strong>Email:</strong> {{ lead.email }}</p>
                    <p v-if="lead.phone"><strong>Phone:</strong> {{ lead.phone }}</p>
                    <p v-if="lead.company"><strong>Company:</strong> {{ lead.company }}</p>
                    <p v-if="lead.notes" class="text-sm"><strong>Notes:</strong> {{ lead.notes }}</p>
                  </div>
                </div>

                <button
                  @click="openConversionModal(lead)"
                  class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition flex items-center gap-2"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                  </svg>
                  Convert to Client
                </button>
              </div>

              <!-- History -->
              <div class="mt-4">
                <button
                  @click="toggleHistory(lead.id)"
                  class="flex items-center gap-2 text-blue-600 hover:text-blue-800"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  History ({{ lead.history?.length || 0 }})
                  <svg
                    :class="['w-4 h-4 transition-transform', showHistory[lead.id] ? 'rotate-180' : '']"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>

                <div v-if="showHistory[lead.id]" class="mt-3 space-y-2 bg-gray-50 p-3 rounded-lg">
                  <div
                    v-for="entry in lead.history"
                    :key="entry.id"
                    class="text-sm border-l-4 border-blue-400 pl-3 py-1"
                  >
                    <p class="font-medium text-gray-800">{{ entry.action }}</p>
                    <p class="text-gray-600">{{ entry.details }}</p>
                    <p class="text-xs text-gray-500 mt-1">{{ formatDate(entry.created_at) }}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Clients Tab -->
        <div v-if="activeTab === 'clients'" class="p-6">
          <div v-if="clients.length === 0" class="text-center py-12 text-gray-500">
            <p class="text-lg">No clients yet. Convert leads to clients to see them here.</p>
          </div>

          <div v-else class="space-y-4">
            <div
              v-for="client in clients"
              :key="client.id"
              class="border border-gray-200 rounded-lg p-4 hover:shadow-lg transition"
            >
              <div class="flex justify-between items-start">
                <div class="flex-1">
                  <div class="flex items-center gap-3">
                    <h3 class="text-xl font-semibold text-gray-800">{{ client.name }}</h3>
                    <span class="px-3 py-1 bg-green-100 text-green-800 text-sm rounded-full font-medium">
                      Client
                    </span>
                  </div>
                  <div class="mt-2 space-y-1 text-gray-600">
                    <p v-if="client.email"><strong>Email:</strong> {{ client.email }}</p>
                    <p v-if="client.phone"><strong>Phone:</strong> {{ client.phone }}</p>
                    <p v-if="client.company"><strong>Company:</strong> {{ client.company }}</p>
                    <p class="text-sm text-gray-500">
                      <strong>Converted:</strong> {{ formatDate(client.converted_at) }}
                    </p>
                  </div>
                </div>

                <button
                  @click="openNoteModal(client)"
                  class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition flex items-center gap-2"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                  Add Note
                </button>
              </div>

              <!-- History -->
              <div class="mt-4">
                <button
                  @click="toggleHistory(client.id)"
                  class="flex items-center gap-2 text-blue-600 hover:text-blue-800"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  Full History ({{ client.history?.length || 0 }})
                  <svg
                    :class="['w-4 h-4 transition-transform', showHistory[client.id] ? 'rotate-180' : '']"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>

                <div v-if="showHistory[client.id]" class="mt-3 space-y-2 bg-gray-50 p-3 rounded-lg max-h-96 overflow-y-auto">
                  <div
                    v-for="entry in client.history"
                    :key="entry.id"
                    class="text-sm border-l-4 border-green-400 pl-3 py-1"
                  >
                    <p class="font-medium text-gray-800">{{ entry.action }}</p>
                    <p class="text-gray-600">{{ entry.details }}</p>
                    <p class="text-xs text-gray-500 mt-1">{{ formatDate(entry.created_at) }}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Conversion Modal -->
    <div
      v-if="showConversionModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
    >
      <div class="bg-white rounded-2xl p-6 max-w-md w-full">
        <h3 class="text-2xl font-bold mb-4">Convert Lead to Client</h3>
        <p class="text-gray-600 mb-4">
          Converting: <strong>{{ selectedLead?.name }}</strong>
        </p>
        <textarea
          v-model="conversionNote"
          placeholder="Add conversion notes (required)..."
          class="w-full border border-gray-300 rounded-lg p-3 h-32 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        ></textarea>
        <div class="flex gap-3 mt-4">
          <button
            @click="convertToClient"
            :disabled="!conversionNote.trim()"
            class="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition"
          >
            Convert to Client
          </button>
          <button
            @click="closeConversionModal"
            class="px-4 py-2 bg-gray-300 text-gray-700 rounded-lg hover:bg-gray-400 transition"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>

    <!-- Note Modal -->
    <div
      v-if="showNoteModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
    >
      <div class="bg-white rounded-2xl p-6 max-w-md w-full">
        <h3 class="text-2xl font-bold mb-4">Add Note</h3>
        <p class="text-gray-600 mb-4">
          Client: <strong>{{ selectedClient?.name }}</strong>
        </p>
        <textarea
          v-model="newNote"
          placeholder="Add a note..."
          class="w-full border border-gray-300 rounded-lg p-3 h-32 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        ></textarea>
        <div class="flex gap-3 mt-4">
          <button
            @click="addNote"
            :disabled="!newNote.trim()"
            class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition"
          >
            Add Note
          </button>
          <button
            @click="closeNoteModal"
            class="px-4 py-2 bg-gray-300 text-gray-700 rounded-lg hover:bg-gray-400 transition"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios';

export default {
  name: 'CallCenterCRM',
  data() {
    return {
      activeTab: 'leads',
      searchTerm: '',
      leads: [],
      clients: [],
      showHistory: {},
      showConversionModal: false,
      showNoteModal: false,
      selectedLead: null,
      selectedClient: null,
      conversionNote: '',
      newNote: '',
      importing: false
    };
  },
  mounted() {
    this.fetchLeads();
    this.fetchClients();
  },
  methods: {
    async fetchLeads() {
      try {
        const response = await axios.get('/api/leads', {
          params: { search: this.searchTerm }
        });
        this.leads = response.data;
      } catch (error) {
        console.error('Error fetching leads:', error);
        alert('Error loading leads');
      }
    },
    async fetchClients() {
      try {
        const response = await axios.get('/api/leads/clients', {
          params: { search: this.searchTerm }
        });
        this.clients = response.data;
      } catch (error) {
        console.error('Error fetching clients:', error);
        alert('Error loading clients');
      }
    },
    handleSearch() {
      if (this.activeTab === 'leads') {
        this.fetchLeads();
      } else {
        this.fetchClients();
      }
    },
    async handleFileUpload(event) {
      const file = event.target.files[0];
      if (!file) return;

      const formData = new FormData();
      formData.append('file', file);

      this.importing = true;
      try {
        await axios.post('/api/leads/import', formData, {
          headers: { 'Content-Type': 'multipart/form-data' }
        });
        alert('Leads imported successfully!');
        this.fetchLeads();
      } catch (error) {
        console.error('Error importing leads:', error);
        alert('Error importing leads. Please check the file format.');
      } finally {
        this.importing = false;
        event.target.value = '';
      }
    },
    openConversionModal(lead) {
      this.selectedLead = lead;
      this.conversionNote = '';
      this.showConversionModal = true;
    },
    closeConversionModal() {
      this.selectedLead = null;
      this.conversionNote = '';
      this.showConversionModal = false;
    },
    async convertToClient() {
      if (!this.conversionNote.trim()) return;

      try {
        await axios.post(`/api/leads/${this.selectedLead.id}/convert`, {
          note: this.conversionNote
        });
        alert('Lead converted to client successfully!');
        this.closeConversionModal();
        this.fetchLeads();
        this.fetchClients();
        this.activeTab = 'clients';
      } catch (error) {
        console.error('Error converting lead:', error);
        alert('Error converting lead');
      }
    },
    openNoteModal(client) {
      this.selectedClient = client;
      this.newNote = '';
      this.showNoteModal = true;
    },
    closeNoteModal() {
      this.selectedClient = null;
      this.newNote = '';
      this.showNoteModal = false;
    },
    async addNote() {
      if (!this.newNote.trim()) return;

      try {
        await axios.post(`/api/leads/${this.selectedClient.id}/note`, {
          note: this.newNote
        });
        alert('Note added successfully!');
        this.closeNoteModal();
        this.fetchClients();
      } catch (error) {
        console.error('Error adding note:', error);
        alert('Error adding note');
      }
    },
    toggleHistory(id) {
      this.showHistory = {
        ...this.showHistory,
        [id]: !this.showHistory[id]
      };
    },
    formatDate(dateString) {
      return new Date(dateString).toLocaleString();
    }
  }
};
</script>

<style scoped>
/* Add any additional custom styles here if needed */
</style>