import { Controller, Get, Param, Query } from '@nestjs/common';
import {
  ApiOperation,
  ApiParam,
  ApiQuery,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { ApiErrorResponseDto } from '../../common/dto/api-response.dto';
import { ParseObjectIdPipe } from '../../common/pipes/parse-object-id.pipe';
import { CategoriesService } from './categories.service';
import { CategoryResponseDto } from './dto/category-response.dto';

@ApiTags('Categories')
@Controller('categories')
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Get()
  @ApiOperation({ summary: 'List all active marketplace categories' })
  @ApiQuery({
    name: 'parentId',
    required: false,
    description:
      'Optional filter by parent category ObjectId, or "root" for top-level categories only',
  })
  @ApiResponse({
    status: 200,
    description: 'List of active categories ordered by sortOrder',
    type: [CategoryResponseDto],
  })
  async findAll(@Query('parentId') parentId?: string) {
    return this.categoriesService.findAll(parentId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get category details by ID' })
  @ApiParam({ name: 'id', description: 'Category MongoDB ObjectId' })
  @ApiResponse({
    status: 200,
    description: 'Category details returned',
    type: CategoryResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Category not found',
    type: ApiErrorResponseDto,
  })
  async findOne(@Param('id', ParseObjectIdPipe) id: string) {
    return this.categoriesService.findById(id);
  }
}
